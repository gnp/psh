package Psh2::Parser;

use strict;

# constants
sub T_REDIRECT() { 3; }
sub T_OR() { 5; }
sub T_AND() { 6; }
sub T_EXECUTE() { 1; }

# generate and cache regexpes
my %quotehash= qw|' ' " " q[ ] qq[ ]|;
my %quotedquotes= ("'" => "\'", "\"" => "\\\"", 'q[' => "\\]",
		   'qq[' => "\\]");
my %nesthash=  ('('=> ')', '$(' => ')',
		'{'=> '}', '${' => '}',
		'['=> ']',
	       );

my $part2= '\\\'|\\"|q\\[|qq\\[';
my $part1= '(\\n|\\|\\||\\&\\&|\\||;|\&>|\\&|>>|>|<|=|\\$\\{|\\$\\(|\\(|\\)|\\{|\\}|\\[|\\])';
my $regexp= qr[^((?:[^\\]|\\.)*?)(?:$part1|($part2))(.*)$]s;

my %tmp_tokens=
  (
   '||' => 1, '&&' => 2,
   ';' => 3, "\n" => 4,
   '&' => 5,
   '|' => 6,
   '>' => 7,
   '>>' => 8,
   '&>' => 9,
   '<'  => 10,
  );

############################################################################
##
## Split up lines into handy parts
##
############################################################################

sub decompose {
    my ($psh, $line, $alias_disabled, $no_wordsplit)= @_;

    if ($line=~/^[a-zA-Z0-9]*$/ and index($line,"\n")==-1) { # perl 5.6 bug
	if ($psh->{aliases} and $psh->{aliases}{$line} and
	    !$alias_disabled->{$line}) {
	    local $alias_disabled->{$line}= 1;
	    return decompose($psh, $psh->{aliases}{$line}, $alias_disabled);
	}
	return [$line];
    }

    my @pieces= ('');
    my $start_new_piece= 0;

    while ($line) {
	if ($start_new_piece) {
	    push @pieces, '';
	    $start_new_piece= 0;
	}

	my ($prefix, $delimiter, $quote, $rest) =
	    $line=~ $regexp;

	if (defined $delimiter) {
	    $pieces[$#pieces] .= $prefix;
	    if (length($pieces[$#pieces])) {
		push @pieces, $delimiter;
	    } else {
		$pieces[$#pieces]= $delimiter;
	    }
	    $start_new_piece= 1;
	    $line= $rest;
	} elsif (defined $quote) {
	    my ($rest_of_quote, $remainder);
	    if ($quote eq 'qq[' or $quote eq '"') {
		($rest_of_quote, $remainder)=
		  ($rest =~ m/^((?:[^\\]|\\.)*?)$quotedquotes{$quote}(.*)$/s);
	    } elsif ($quote eq "'") {
		($rest_of_quote, $remainder)=
		  ($rest =~ m/^((?:[^\']|\'\')*)\'(.*)$/s);
	    } else {
		($rest_of_quote, $remainder)=
		  ($rest =~ m/^(.*?)$quotedquotes{$quote}(.*)$/s);
	    }
	    if (defined $rest_of_quote) {
		$pieces[$#pieces].= $prefix;
		my $tmp= join('',$quote, $rest_of_quote, $quotehash{$quote});
		if (length($pieces[$#pieces])) {
		    push @pieces, $tmp;
		} else {
		    $pieces[$#pieces]= $tmp;
		}
		$line= $remainder;
		$start_new_piece=1;
	    } else { # can't find matching quote, give up
		die "parse: needmore: quote: missing $quote";
	    }
	} else {
	    last;
	}
    }
    if (length($line)) {
	$pieces[$#pieces].= $line;
    }
    my @pieces2= ();
    my @open= ();
    my @tmp= ();
    my $start_of_command= 1;
    my $language_mode= 0;

    foreach my $piece (@pieces) {
        if ($start_of_command and length($piece)>1 and
            $piece=~ /^(\S+\:)(.*)$/) {
            push @pieces2, $1;
            $piece=$2;
            $language_mode=1;
        }
	if (length($piece)<3) {
            if ($piece eq '[' or $piece eq '(' or $piece eq '{' or
	        $piece eq '${'or $piece eq '$(') {
                push @open, $piece;
            } elsif ($piece eq '}' or $piece eq ')' or $piece eq ']') {
                if (@open and $piece eq $nesthash{$open[0]}) {
                    pop @open;
                }
            }
        }
        if (@open) {
            push @tmp, $piece;
        } elsif (@tmp) {
	    my $tmp= join('', @tmp, $piece);
	    @tmp= ();
	    if (!$language_mode and
                (substr($tmp,0,2) eq '$(' or
                 substr($tmp,0,2) eq '${')) {
		$tmp= expand_dollar($psh,$tmp);
	    }
	    push @pieces2, $tmp;
	} else {
	    if ($start_of_command and $psh->{aliases}) {
		if ($piece=~/^(\s*)([a-zA-Z0-9_.-]+)(\s*)$/ or
		    $piece=~/^(\s*)([a-zA-Z0-9_.-]+)(\s.*)$/) {
		    my ($pre, $main, $post)= ($1, $2, $3);

		    if ($main and $psh->{aliases}{$main} and
			!$alias_disabled->{$main}) {
			local $alias_disabled->{$main}= 1;
			my @tmppiec= @{decompose($psh, $psh->{aliases}{$main},
						 $alias_disabled, 1)};
			$tmppiec[0]= $pre.$tmppiec[0];
			push @pieces2, @tmppiec;
			$piece= $post;
		    }
		}
	    }
            $start_of_command= 0;

            unless ($language_mode) {
                $piece=~ s/(?<!\\)(\$[a-zA-Z0-9_]+)/&expand_dollar($psh,$1)/ge;
                $piece=~ s/(?<!\\)(\$\([a-zA-Z0-9_]+\))/&expand_dollar($psh,$1)/ge;
            }

	    if ($tmp_tokens{$piece}) {
                $language_mode=0;
		push @pieces2, [$tmp_tokens{$piece}];
                if ($tmp_tokens{$piece}<7) {
                    $start_of_command=1;
                    next;
                }
	    } else {
		push @pieces2, $piece;
	    }
        }
	$start_of_command= 0;
    }
    if (@open) {
	die "parse: needmore: nest: missing @open";
    }
    return \@pieces2 if $no_wordsplit;

    my @pieces3= ();
    my $space= 0;
    $start_of_command=1;
    $language_mode=0;
    foreach my $piece (@pieces2) {
        if ($language_mode) {
            push @pieces3, $piece;
            if (ref $piece) {
                $language_mode=0;
                $space=1;
            }
            next;
        }
        if ($start_of_command and length($piece)>1 and
            substr($piece,-1) eq ':') {
            push @pieces3, $piece;
            $language_mode=1;
            next;
        }
        $start_of_command=0;
	if (ref $piece) {
	    push @pieces3, $piece;
            if ($piece->[0]<7) {
                $start_of_command=1;
            }
	    $space= 1;
	    next;
	}

        my $char= substr($piece,0,1);
        if ( $char eq '{' or $char eq '(' or $char eq '[' or
             $piece eq '=') {
            push @pieces3, $piece;
            $space= 1;
        } elsif ( $char eq '"' or $char eq "'" or
                  (length($piece)>2 and substr($piece,0,2) eq 'q[') or
                  (length($piece)>3 and substr($piece,0,3) eq 'qq[')) {
            _clean_word(\$piece);
            if (!$space and @pieces3>0) {
                my $old= pop @pieces3;
                $piece= $old. $piece
            }
            push @pieces3, $piece;
            $space= 0;
        } else {
            @tmp= split /(?<!\\)\s+/, $piece, -1;
            if ($tmp[0] eq '') {
                shift @tmp;
                $space= 1;
            }
            if (!$space and @pieces3>0) {
                my $old= pop @pieces3;
                $tmp[0]=$old.$tmp[0];
            }
            if ($tmp[$#tmp] eq '') {
                $space=1;
                pop @tmp;
            } else {
                $space=0;
            }
            push @pieces3, @tmp;
        }
    }
    return \@pieces3;
}

sub expand_dollar {
    my ($psh, $piece)= @_;
    if (length($piece)>2 and substr($piece,0,2) eq '${') {
	return qq['$piece'];
    }
    else {
	if (substr($piece,0,2) eq '$(') {
	    $piece= substr($piece,2,-1);
	} else {
	    $piece= substr($piece,1);
	}
	my $tmp= $ENV{uc($piece)}||'';
	return $tmp;
    }
}

sub _remove_backslash {
    my $text= shift;

    $$text=~ s/\\\\/\001/g;
    $$text=~ s/\\t/\t/g;
    $$text=~ s/\\n/\n/g;
    $$text=~ s/\\r/\r/g;
    $$text=~ s/\\f/\f/g;
    $$text=~ s/\\b/\b/g;
    $$text=~ s/\\a/\a/g;
    $$text=~ s/\\e/\e/g;
    $$text=~ s/\\(0[0-7][0-7])/chr(oct($1))/ge;
    $$text=~ s/\\(x[0-9a-fA-F][0-9a-fA-F])/chr(oct($1))/ge;
    $$text=~ s/\\(.)/$1/g;
    $$text=~ s/\001/\\/g;
}

sub ungroup {
    my $text= shift;
    if (substr($text,0,1) eq '(' and
	substr($text,-1,1) eq ')') {
	return substr($text,1,-1);
    } elsif (substr($text,0,1) eq '{' and
	     substr($text,-1,1) eq '}') {
	return substr($text,1,-1);
    }
    return $text;
}

sub is_group {
    my $text= shift;
    if (substr($text,0,1) eq '(' or
        substr($text,0,1) eq '{') {
	return 1;
    }
    return 0;
}

############################################################################
##
## Convert line pieces into tokens
##
############################################################################

sub _parse_fileno {
    my ($parts, $fileno)= @_;
    my $bothflag= 0;
    while (@$parts>0) {
	my $tmp= shift @$parts;
	next if $tmp=~ /^\s+$/;
	if ($tmp=~ /^\[(.+?)\]$/) {
	    $tmp= $1;
	    my @tmp= split('=', $tmp);
	    if (@tmp>2) {
		die "parse: fileno: more than one = sign";
	    }
	    if (@tmp<2) {
		push @tmp, $fileno->[1];
	    }
	    if (@tmp==2 and !$tmp[0]) {
		$tmp[0]= $fileno->[0];
	    }
	    my @result=();
	    foreach (@tmp) {
		no strict 'refs';
		if (lc($_) eq 'all') {
		    $_= 1;
		    $bothflag= 1;
		}
		if (/^\d+$/) {
		    push @result, $_+0;
		} else {
		    # TODO: Add Perl Filehandle access
		}
	    }
	    @$fileno= @result;
	} else {
	    unshift @$parts, $tmp;
	}
	last;
    }
    return $bothflag;
}

sub _clean_word {
    my $tmp= shift;
    if (length($$tmp)>1) {
	if (length($$tmp)> 3 and substr($$tmp,0,2) eq 'qq[') {
	    $$tmp= substr($$tmp,3,-1);
	    _remove_backslash($tmp);
	} elsif (substr($$tmp,0,1) eq "'") {
	    $$tmp= substr($$tmp,1,-1);
	    $$tmp=~ s/\'\'/\'/g;
	} elsif (substr($$tmp,0,1) eq '"') {
	    $$tmp= substr($$tmp,1,-1);
	    _remove_backslash($tmp);
	} elsif (substr($$tmp,0,2) eq 'q[') {
	    $$tmp= substr($$tmp,2,-1);
	} else {
	    $$tmp=~ s/\\//g;
	}
    }
}

sub make_tokens {
    my ($psh, $line)= @_;
    my @parts= @{decompose($psh, $line, {})};

    my $words=[];
    my $redirects=[];
    my $pipes=[$words, $redirects];
    my @tokens= ();

    my $tmp;
    while (defined ($tmp= shift @parts)) {
	if (ref $tmp) {
	    my $num= $tmp->[0];
	    if ($num==1 or $num==2) {
		push @tokens, [1, 1, $pipes],
		  [ $num==1? T_OR: T_AND ];
		$words= [];
		$redirects= [];
		$pipes= [$words, $redirects];
		next;
	    } elsif ($num==3 or $num==4 ) {
		push @tokens, [1, 1, $pipes];
		$words= [];
		$redirects= [];
		$pipes= [$words, $redirects];
		next;
	    } elsif ($num==5) {
		push @tokens, [1, 0, $pipes];
		$words= [];
		$redirects= [];
		$pipes= [$words, $redirects];
		next;
	    } elsif ($num==6) {
		my @fileno= (1,0);
		my $bothflag= 0;
		$bothflag ||= _parse_fileno(\@parts, \@fileno);
		push @$redirects, [ 3, '>&', $fileno[0], 'chainout'];
		if ($bothflag) {
		    push @$redirects, [ 3, '>&', 2, $fileno[0]];
		}
		$redirects= [ [3, '<&', $fileno[1], 'chainin'] ];
		$words= [];
		push @$pipes, $words, $redirects;
		next;
	    } elsif ( $num>6 and $num<10 ) {
		my $bothflag= 0;
		if ($num==9) {
		    $bothflag= 1;
		    $num= 7;
		}
		my @fileno= (1,0);
		my $file;

		$bothflag ||= _parse_fileno(\@parts, \@fileno);
		if ($fileno[1]==0) {
		    $file= shift @parts;
		    die "parse: redirection >: file missing" unless $file;
		    push @$redirects, [3, $num==7?'>':'>>', $fileno[0], $file];
		} else {
		    push @$redirects, [3, '>&', @fileno];
		}
		if ($bothflag) {
		    push @$redirects, [3, '>&', 2, $fileno[0]];
		}
		next;
	    } elsif ($num==10) {
		my $file;
		my @fileno= (0,0);
		_parse_fileno(\@parts, \@fileno);
		if ($fileno[0]==0) {
		    $file= shift @parts;
		    die "parse: redirection <: file missing" unless $file;
		    push @$redirects, [3, '<', $fileno[1], $file];
		} else {
		    push @$redirects, [3, '<&', $fileno[1], $fileno[0]];
		}
		next;
	    } else {
		die "Unknown token: $num\n";
	    }
	}
	push @$words, $tmp;
    }
    if (@$words) {
	push @tokens, [ 1, 1, $pipes ];
    }
    return \@tokens;
}

sub parse_line {
    my ($psh, $line)= @_;
    return [] if substr( $line, 0, 1) eq '#' or $line=~/^\s*$/;

    my $tokens= make_tokens( $psh, $line );
    my @elements= ();

    while ( @$tokens) {
	my $token= shift @$tokens;
	if ($token->[0] == 1) {
	    my @simple=();
	    my $is_pipe= (@{$token->[2]}>2);
	    while (@{$token->[2]}) {
		my $words= shift @{$token->[2]};
		my $options= shift @{$token->[2]};
		if (!@$words) {
		    die 'parse: missing command' if $is_pipe;
		    next;
		}
		push @simple, _parse_simple( $words, $options, $psh);
	    }
	    push @elements, [ 1, $token->[1], @simple ];
	} else {
	    push @elements, $token;
	}
    }
    return \@elements;
}

sub _parse_simple {
    my @words= @{shift()};
    my @options= @{shift()};
    my $psh= shift;

    my $opt= {};

    while ($words[0] and length($words[0])>5 and
	    ($words[0] eq 'noglob' or $words[0] eq 'noexpand' or
	     $words[0] eq 'nobuiltin' or $words[0] eq 'builtin')) {
	$opt->{$words[0]}= 1;
	shift @words;
    }
    my $first= $words[0];

    return () if !@words or (@words==1 and $first eq '');

    if (substr($first,0,1) eq '\\') {
	$first= substr($first,1);
    }

    my $line= join ' ', @words;

    if (is_group($words[0])) {
	return ['reparse', undef, \@options, \@words, $line, $opt, undef];
    }

    if (length($first)>1 and substr($first,-1) eq ':') {
	my $tmp= lc(substr($first,0,-1));
	if (exists $psh->{language}{$tmp}) {
	    eval 'use Psh2::Language::'.ucfirst($tmp);
	    if ($@) {
		print STDERR $@;
		# TODO: Error handling
	    }
	    return [ 'call', 'Psh2::Language::'.ucfirst($tmp).'::execute', \@options, \@words, $line, $opt, undef];
	} else {
	    die "parse: unsupported language $tmp";
	}
    }

    @words= @{glob_expansion($psh, \@words)} unless $opt->{noglob};

    unless ($opt->{nobuiltin}) {
	my $tmp;
	if ($tmp= $psh->is_builtin($first)) {
	    eval 'use Psh2::Builtins::'.ucfirst($tmp);
	    if ($@) {
		print STDERR $@;
		# TODO: Error handling
	    }
	    return [ 'call', 'Psh2::Builtins::'.ucfirst($tmp).'::execute', \@options, \@words, $line, $opt, undef];
	}
    }
    unless ($opt->{builtin}) {
        my $full_fun_name= $Psh2::Language::Perl::current_package.'::'.$first;
        if (exists $psh->{function}{$full_fun_name}) {
            return [ 'call', $psh->{function}{$full_fun_name}[0], \@options, \@words,
                     $line, $opt, $psh->{function}{$full_fun_name}[1]];
        }
	my $tmp= $psh->which($first);
	if ($tmp) {
	    return [ 'execute', $tmp, \@options, \@words, $line, $opt, undef];
	}
	foreach my $strategy (@{$psh->{strategy}}) {
	    my $tmp= eval {
		$strategy->applies(\@words, $line);
	    };
	    if ($@) {
		# TODO: Error handling
	    } elsif ($tmp) {
		return [ $strategy, $tmp, \@options, \@words, $line, $opt, undef];
	    }
	}
    }
    die "duh: $first";
}

sub glob_expansion {
    my ($psh, $words)= @_;
    my @retval  = ();

    for my $word (@{$words}) {
	if (
	    (substr($word,0,1) ne '[' and
	     index($word,'*')==-1 and
	     index($word,'?')==-1 and
	     index($word,'~')==-1) or
	     (substr($word,0,1) eq '"' and substr($word,-1) eq '"') or
	     (substr($word,0,1) eq '`' and substr($word,-1) eq '`') or
	     (substr($word,0,1) eq "'" and substr($word,-1) eq "'") or
	     (substr($word,0,1) eq '(' and substr($word,-1) eq ')') or
	     (substr($word,0,1) eq '{' and substr($word,-1) eq '}')
	   ) {
	    push @retval, $word;
	} else {
	    my @results = $psh->glob($word);
	    if (scalar(@results) == 0) {
		push @retval, $word;
	    } else {
		push @retval, @results;
	    }
	}
    }
    return \@retval;
}


1;
