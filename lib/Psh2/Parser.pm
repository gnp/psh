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
		   'qq[' => "\\]" );
my %nesthash=  ('('=> ')', '$(' => ')',
		'{'=> '}', '${' => '}',
		'['=> ']',
	       );

my $part2= '\\\'|\\"|q\\[|qq\\[';
my $part1= '(\\n|\\|\\||\\&\\&|\\||;|\&>|\\$\\&|\\&|>>|>|<|\\$\\{|\\$\\(|\\(|\\)|\\{|\\}|\\[|\\])';
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
    my ($psh, $line, $no_wordsplit)= @_;

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
        if (!@open and $start_of_command and length($piece)>1 and
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
                if (@open and $piece eq $nesthash{$open[$#open]}) {
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
            if (@pieces2>1 and $pieces2[$#pieces2-1] eq '$&') {
                my $funname= pop @pieces2; pop @pieces2;
                $tmp= expand_dollar_function($psh,$funname,$tmp);
            }
            push @pieces2, $tmp;
	} else {
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
        if ( $char eq '{' or $char eq '(' or $char eq '[') {
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
            if (@tmp) {
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
                @tmp= map { s/\\(.)/$1/g;$_ } @tmp;
                push @pieces3, @tmp;
            }
        }
    }
    return \@pieces3;
}

sub _parse_control_char {
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
    my $firstchar= substr($text,0,1);
    my $lastchar= substr($text,-1,1);
    if ($firstchar eq '(' and $lastchar eq ')') {
	return substr($text,1,-1);
    } elsif ($firstchar eq '{' and $lastchar eq '}') {
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
	    _parse_control_char($tmp);
	} elsif (substr($$tmp,0,1) eq "'") {
	    $$tmp= substr($$tmp,1,-1);
	    $$tmp=~ s/\'\'/\'/g;
	} elsif (substr($$tmp,0,1) eq '"') {
	    $$tmp= substr($$tmp,1,-1);
	    _parse_control_char($tmp);
	} elsif (substr($$tmp,0,2) eq 'q[') {
	    $$tmp= substr($$tmp,2,-1);
	} else {
	    $$tmp=~ s/\\//g;
	}
    }
}

sub make_tokens {
    my ($psh, $line)= @_;
    my @parts= @{decompose($psh, $line)};

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

                # order is important...
                my @tmp= ([ 3, '>&', $fileno[0], 'chainout']);
		if ($bothflag) {
		    push @tmp, [ 3, '>&', 2, $fileno[0]];
		}
                unshift @$redirects, @tmp;

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

                my @tmp= ();
		$bothflag ||= _parse_fileno(\@parts, \@fileno);
		if ($fileno[1]==0) {
		    $file= shift @parts;
		    die "parse: redirection >: file missing" unless $file;
		    push @tmp, [3, $num==7?'>':'>>', $fileno[0], $file];
		} else {
		    push @tmp, [3, '>&', @fileno];
		}
		if ($bothflag) {
		    push @tmp, [3, '>&', 2, $fileno[0]];
		}
                unshift @$redirects, @tmp;
		next;
	    } elsif ($num==10) {
		my $file;
		my @fileno= (0,0);
		_parse_fileno(\@parts, \@fileno);
		if ($fileno[0]==0) {
		    $file= shift @parts;
		    die "parse: redirection <: file missing" unless $file;
		    unshift @$redirects, [3, '<', $fileno[1], $file];
		} else {
		    unshift @$redirects, [3, '<&', $fileno[1], $fileno[0]];
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
    return [] if ord( $line)==35 or $line=~/^\s*$/;

    my $tokens= make_tokens( $psh, $line );
    my @elements= ();

    while ( @$tokens) {
	my $token= shift @$tokens;
	if ($token->[0] == 1) {
	    my @simple=();
	    my $is_pipe= (@{$token->[2]}>2);
	    while (@{$token->[2]}) {
		my $words= shift @{$token->[2]};
		my $redirects= shift @{$token->[2]};
		if (!@$words) {
		    die 'parse: missing command' if $is_pipe;
		    next;
		}
		push @simple, _parse_simple( $words, $redirects, $psh);
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
    my @redirects= @{shift()};
    my $psh= shift;

    my $opt= {};
    my $options= { redirects => \@redirects,
                   env => {},
                   opt => $opt };

    while ($words[0] and length($words[0])>5 and
	    ($words[0] eq 'noglob' or $words[0] eq 'noexpand' or
             $words[0] eq 'command' or $words[0] eq 'noalias' or
	     $words[0] eq 'nobuiltin' or $words[0] eq 'builtin')) {
	$opt->{$words[0]}= 1;
	shift @words;
    }
    return () if !@words or (@words==1 and $words[0] eq '');

    parse_variables($psh, \@words, $options);
    return () unless @words;

    if (ord($words[0])==92) { # backslash
	$words[0]= substr($words[0],1);
    } elsif (!$opt->{noalias}) {
        if ($psh->{aliases}{$words[0]}) {
            my @tmp= split /\s+/, $psh->{aliases}{$words[0]};
            shift @words;
            unshift @words, @tmp;
        }
    }

    my $first= $words[0];
    my $line= join ' ', @words;

    if (is_group($first)) {
	return ['reparse', undef, $options, \@words, $line, undef];
    }

    if (length($first)>1 and substr($first,-1) eq ':') {
	my $tmp= lc(substr($first,0,-1));
	if (exists $psh->{language}{$tmp}) {
	    eval 'use Psh2::Language::'.ucfirst($tmp);
	    if ($@) {
		print STDERR $@;
		# TODO: Error handling
	    }
	    return [ 'call', 'Psh2::Language::'.ucfirst($tmp).'::execute', $options, \@words, $line, undef];
	} else {
	    die "parse: unsupported language $tmp";
	}
    }

    @words= @{glob_expansion($psh, \@words)} unless $opt->{noglob};

    if (!$opt->{nobuiltin} and !$opt->{command}) {
	my $tmp;
	if ($tmp= $psh->is_builtin($first)) {
	    eval 'use Psh2::Builtins::'.ucfirst($tmp);
	    if ($@) {
		print STDERR $@;
		# TODO: Error handling
	    }
	    return [ 'call', 'Psh2::Builtins::'.ucfirst($tmp).'::execute', $options, \@words, $line, undef];
	}
    }
    if (!$opt->{builtin}) {
        if (!$opt->{command}) {
            my $full_fun_name= $psh->{current_package}.'::'.$first;
            if (exists $psh->{function}{$full_fun_name}) {
                return [ 'call', $psh->{function}{$full_fun_name}[0], $options, \@words,
                         $line, $psh->{function}{$full_fun_name}[1]];
            }
            foreach my $strategy (@{$psh->{strategy}}) {
                my $tmp= eval {
                    $strategy->applies(\@words, $line);
                };
                if ($@) {
                    # TODO: Error handling
                } elsif ($tmp) {
                    return [ $strategy, $tmp, $options, \@words, $line, undef];
                }
            }
        }
	my $tmp= $psh->which($first);
	if ($tmp) {
	    return [ 'execute', $tmp, $options, \@words, $line, undef];
	}
    }
    $psh->printerrln($psh->gt('syntax error').': '.$first);
    return ();
}

sub glob_expansion {
    my ($psh, $words)= @_;
    my @retval  = ();

    for my $word (@{$words}) {
        my $firstchar= substr($word,0,1);
        my $lastchar= substr($word,-1);
	if (
	    ($firstchar ne '[' and
	     index($word,'*')==-1 and
	     index($word,'?')==-1 and
	     index($word,'~')==-1) or
	     ($firstchar eq '"' and $lastchar eq '"') or
	     ($firstchar eq '`' and $lastchar eq '`') or
	     ($firstchar eq "'" and $lastchar eq "'") or
	     ($firstchar eq '(' and $lastchar eq ')') or
	     ($firstchar eq '{' and $lastchar eq '}')
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

############################################################################
##
## Variable handling
##
############################################################################

sub set_internal_variables {
    my ($psh, $vars)= @_;

    while (my ($key, $val)= each %$vars) {
        my $subscript= -1;
        if ($key=~/^(.*)\[(\d+)\]$/) {
            ($key,$subscript)=($1,$2);
        }
        my $var= $psh->get_variable($key);
        $var->value($subscript, $val);
    }
}


sub expand_dollar {
    my ($psh, $piece)= @_;
    if (length($piece)>2 and substr($piece,0,2) eq '$(') {
        return "'".$psh->process_backtick(substr($piece,2,-1))."'";
    }
    else {
	if (substr($piece,0,2) eq '${') {
	    $piece= substr($piece,2,-1);
	} else {
	    $piece= substr($piece,1);
	}
        my $subscript= -1;
        if ($piece=~/^(.*)\[(\d)+\]$/ ) {
            ($piece,$subscript)=($1,$2);
        }
        my $var= $psh->get_variable($piece);
        return $var->value($subscript);
    }
}

sub expand_dollar_function {
    my ($psh, $name, $args)= @_;
    if ($name eq 'perl') {
        return eval substr($args,1,-1);
    }
    elsif ($name eq 'substr') {
        print STDERR "-$args-";
    }
    else {
        die "unknown function: $name";
    }
    return '';
}

sub parse_variables {
    my ($psh, $words, $options)= @_;

    my $env= {};
    my $opt= $options->{opt};

    while (@$words) {
        my ($key, $val);
        if (@$words>2 and $words->[0]=~/^[a-zA-Z0-9_-]+$/ and
               $words->[1]=~/^\[\d+\]$/ and
               substr($words->[2],0,1) eq '=') {
            $key=qq[$words->[0]$words->[1]];
            $val=substr($words->[2],1);
            shift @$words; shift @$words; shift @$words;
        }
        elsif (@$words>1 and $words->[0]=~/^[a-zA-Z0-9_-]+\=$/ and
               $words->[1]=~/^\(\s*(.*?)\s*\)$/s) {
            $val= $1;
            $key=substr($words->[0],0,length($words->[0])-1);
            my @val= split /\s+/, $val;
            if (!$opt->{noglob}) {
                @val= @{glob_expansion($psh, \@val)};
            }

            $env->{$key}= \@val;
            shift @$words; shift @$words;
            next;
        }
        elsif ($words->[0]=~/^([a-zA-Z0-9_-]+?)=(.*)$/s) {
            ($key,$val)= ($1,$2);
            shift @$words;
        }
        else {
            last;
        }
        if (!$opt->{noglob}) {
            $val=join(' ',@{glob_expansion($psh, [$val])});
        }
        $env->{$key}= $val;
    }
    if (!@$words) {
        set_internal_variables($psh, $env);
    } else {
        $options->{env}= $env;
    }
}

1;
