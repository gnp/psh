package Psh2::Parser;

use strict;

# constants
sub T_END() { 0; }
sub T_WORD() { 1; }
sub T_PIPE() { 2; }
sub T_REDIRECT() { 3; }
sub T_BACKGROUND() { 4; }
sub T_OR() { 5; }
sub T_AND() { 6; }

sub T_EXECUTE() { 1; }

# generate and cache regexpes
my %quotehash= qw|' ' " " ` `|;
my %nesthash=  qw|( ) { } [ ]|;
my %quotedquotes= ();

my $part2= '(?!a)a';

foreach my $opener (keys %quotehash) {
    $part2.='|'. quotemeta($opener);
    $quotedquotes{$opener}= quotemeta($quotehash{$opener});
}

my $part1= '(\\s+|\\|\\||\\&\\&|\||=>|->|;;|;|\&>|\\&|>>|>|<<|<|\\(|\\)|\\{|\\}|\\[|\\])';
my $regexp= qr[^((?:[^\\\\]|\\\\.)*?)(?:$part1|($part2))(.*)$]s;

############################################################################
##
## Split up lines into handy parts
##
############################################################################

sub decompose {
    my $line= shift;
    my @pieces= ('');
    my $start_new_piece= 0;
    my $fresh_piece= 1;
    my $uquote= 0;

    while ($line) {
	if ($start_new_piece) {
	    push @pieces, '';
	    $start_new_piece= 0;
	    $fresh_piece= 1;
	}
	my ($prefix, $delimiter, $quote, $rest) =
	    $line=~ $regexp;

	if (defined $prefix) {
	    $prefix= remove_backslash($prefix);
	}

	if (defined $delimiter) {
	    $pieces[$#pieces] .= $prefix;
	    if (length($pieces[$#pieces]) or !$fresh_piece) {
		push @pieces, $delimiter;
	    } else {
		$pieces[$#pieces]= $delimiter;
	    }
	    $start_new_piece= 1;
	    $line= $rest;
	} elsif (defined $quote) {
	    my ($rest_of_quote, $remainder)=
		($rest =~ m/^((?:[^\\]|\\.)*?)$quotedquotes{$quote}(.*)$/s);
	    if (defined $rest_of_quote) {
		if ($quote ne "\'") {
		    $rest_of_quote= remove_backslash($rest_of_quote);
		}
		$pieces[$#pieces]= join('', $pieces[$#pieces], $prefix, $quote,
					$rest_of_quote, $quotehash{$quote});
		$line= $remainder;
		$fresh_piece= 0;
	    } else { # can't find matching quote, give up
		$uquote= 1;
		last;
	    }
	} else {
	    if (length($line)) {
		$line= remove_backslash($line);
	    }
	    last;
	}
    }
    if (length($line)) {
	$pieces[$#pieces].= $line;
    }
    return (\@pieces, $uquote);
}

sub remove_backslash {
    my $text= shift;

    $text=~ s/\\\\/\001/g;
    $text=~ s/\\t/\t/g;
    $text=~ s/\\n/\n/g;
    $text=~ s/\\r/\r/g;
    $text=~ s/\\f/\f/g;
    $text=~ s/\\b/\b/g;
    $text=~ s/\\a/\a/g;
    $text=~ s/\\e/\e/g;
    $text=~ s/\\(0[0-7][0-7])/chr(oct($1))/ge;
    $text=~ s/\\(x[0-9a-fA-F][0-9a-fA-F])/chr(oct($1))/ge;
    $text=~ s/\\(.)/$1/g;
    $text=~ s/\001/\\/g;
    return $text;
}

sub unquote {
    my $text= shift;

    if (substr($text,0,1) eq '\'' and
	substr($text,-1,1) eq '\'') {
	$text= substr($text,1,-1);
    } elsif ( substr($text,0,1) eq "\"" and
	      substr($text,-1,1) eq "\"") {
	$text= substr($text,1,-1);
    }
    return $text;
}


# Combine parenthesized parts
sub recombine_parts {
    my @tmpparts= @{shift()};
    my @parts= ();
    my @open= ();
    my @tmp= ();
    foreach (@tmpparts) {
	if (length($_)==1) {
	    if ($_ eq '[' or $_ eq '(' or $_ eq '{') {
		push @open, $_;
	    } elsif ($_ eq '}' or $_ eq ')' or $_ eq ']') {
		my $tmp= pop @open;
		if (!defined $tmp) {
		    die "parse: nest: closed $_";
		}
		if ($nesthash{$tmp} ne $_) {
		    die "parse: nest: wrong $tmp $_";
		}
	    }
	}
	if (@open) {
	    push @tmp, $_;
	} elsif (@tmp) {
	    push @parts, join('', @tmp, $_);
	    @tmp= ();
	} else {
	    push @parts, $_;
	}
    }
    die "parse: nest: open @open" if @open;
    return \@parts;
}

############################################################################
##
## Convert line pieces into tokens
##
############################################################################

sub _parse_fileno {
    my ($parts, $fileno)= @_;
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
}

sub make_tokens {
    my $line= shift;
    my ($partstmp, $openquotes)= decompose($line);
    die "parse: openquotes: $openquotes" if $openquotes;

    my @parts= @{recombine_parts($partstmp)};

    my @tmp= ();
    my @tokens= ();
    my $tmp;
    while (defined ($tmp= shift @parts)) {
	if ($tmp eq '||' or $tmp eq '&&') {
	    push @tokens, @tmp;
	    push @tokens, [T_END], [ $tmp eq '||'? T_OR: T_AND ];
	    @tmp= ();
	} elsif ($tmp eq ';;') {
	    push @tmp, [T_WORD, ';'];
	} elsif ($tmp eq '|') {
	    my @fileno= (1,0);
	    _parse_fileno(\@parts, \@fileno);
	    push @tokens, [ T_REDIRECT, '>&', $fileno[0], 'chainout'];
	    push @tokens, @tmp;
	    push @tokens, [ T_PIPE ];
	    @tmp= ( [T_REDIRECT, '<&', $fileno[1], 'chainin']);
	} elsif ($tmp=~ /^>>?$/ or
		 $tmp eq '&>') {
	    my $bothflag= 0;
	    if ($tmp eq '&>') {
		$bothflag= 1;
		$tmp= '>';
	    }
	    my @fileno= (1,0);
	    my $file;

	    _parse_fileno(\@parts, \@fileno);
	    if ($fileno[1]==0) {
		while (@parts>0) {
		    $file= shift @parts;
		    last if $file !~ /^\s+$/;
		    $file= '';
		}
		die "parse: redirection >: file missing" unless $file;
		push @tmp, [T_REDIRECT, $tmp, $fileno[0], unquote($file)];
	    } else {
		push @tmp, [T_REDIRECT, '>&', @fileno];
	    }
	    if ($bothflag) {
		push @tmp, [T_REDIRECT, '>&', 2, $fileno[0]];
	    }
	} elsif ($tmp eq '<') {
	    my $file;
	    my @fileno= (0,0);
	    _parse_fileno(\@parts, \@fileno);
	    if ($fileno[0]==0) {
		while (@parts>0) {
		    $file= shift @parts;
		    last if $file !~ /^\s+$/;
		    $file= '';
		}
		die "parse: redirection <: file missing" unless $file;
		push @tmp, [T_REDIRECT, '<', $fileno[1], unquote($file)];
	    } else {
		push @tmp, [T_REDIRECT, '<&', $fileno[1], $fileno[0]];
	    }
	} elsif ($tmp eq '&') {
	    push @tokens, @tmp;
	    push @tokens, [T_BACKGROUND], [T_END];
	    @tmp= ();
	} elsif ($tmp eq ';') {
	    push @tokens, @tmp;
	    push @tokens, [T_END];
	    @tmp= ();
	} elsif ($tmp=~ /^\s+$/) {
	} else {
	    push @tmp, [ T_WORD, $tmp];
	}
    }
    push @tokens, @tmp;
    return \@tokens;
}

sub parse_line {
    my $line= shift;
    my $psh= shift;

    return [] if substr( $line, 0, 1) eq '#';

    my $tokens= make_tokens( $line );
    my @elements= ();
    my $element;
    while ( @$tokens > 0 ) {
	$element= _parse_complex( $tokens, $psh);
	return undef unless defined $element; # TODO: Error handling
	push @elements, $element;
	if (@$tokens > 0) {
	    if ($tokens->[0][0] == T_END) {
		shift @$tokens;
	    }
	    if (@$tokens > 0) {
		if ($tokens->[0][0] == T_AND) {
		    shift @$tokens;
		    push @elements, [ T_AND ];
		} elsif ($tokens->[0][0] == T_OR) {
		    shift @$tokens;
		    push @elements, [ T_OR ];
		}
	    }
	}
    }
    return \@elements;
}

sub _parse_complex {
    my $tokens= shift;
    my $psh= shift;
    my $piped= 0;
    my $fg= 1;
    return [ T_EXECUTE, $fg, @{_sub_parse_complex($tokens, \$piped, \$fg, {}, $psh )}];
}

sub _sub_parse_complex {
    my ($tokens, $piped, $fg, $alias_disabled, $psh)= @_;
    my @simple= _parse_simple( $tokens, $piped, $fg, $alias_disabled, $psh);

    while (@$tokens > 0 and $tokens->[0][0] == T_PIPE ) {
	shift @$tokens;
	$$piped= 1;
	push @simple, _parse_simple( $tokens, $piped, $fg, $alias_disabled, $psh);
    }

    if (@$tokens > 0 and $tokens->[0][0] == T_BACKGROUND ) {
	shift @$tokens;
	$$fg= 0;
    }
    return \@simple;
}

sub _is_precommand {
    my $word= shift;
    return 1 if $word eq 'noglob' or $word eq 'noexpand'
      or $word eq 'noalias' or $word eq 'nobuiltin' or
	$word eq 'builtin';
}

sub _parse_simple {
    my ($tokens, $piped, $fg, $alias_disabled, $psh)= @_;
    my (@words, @options, @savetokens, @precom);
    my $opt= {};

    my $firstwords= 1;

    while (@$tokens > 0 and
	  ($tokens->[0][0] == T_WORD or
	   $tokens->[0][0] == T_REDIRECT )) {
	my $token= shift @$tokens;
	if ($token->[0] == T_WORD) {
	    if ($firstwords and
		_is_precommand($token->[1])) {
		push @precom, $token;
		$opt->{$token->[1]}= 1;
	    } else {
		$firstwords= 0;
		push @savetokens, $token;
		push @words, $token->[1];
	    }
	} elsif ($token->[0] == T_REDIRECT) {
	    push @options, $token;
	}
    }

    return () unless @words;

    if (!$opt->{noalias} and $psh->{aliases} and
        $psh->{aliases}->{$words[0]} and
        !$alias_disabled->{$words[0]}) {
	my $alias= $psh->{aliases}->{$words[0]};
	$alias_disabled->{$words[0]}= 1;
	my @tmp= make_tokens($alias);
	unshift @tmp, @precom;
	shift @savetokens;
	push @tmp, @savetokens;
	push @tmp, @options;
	return _sub_parse_complex(\@tmp, $piped, $fg, $alias_disabled, $psh);
    } elsif ($words[0] and substr($words[0],0,1) eq "\\") {
	$words[0]= substr($words[0],1);
    }
    
    my $line= join ' ', @words;
    $psh->{tmp}{options}= $opt;

    if ($words[0] and substr($words[0],-1) eq ':') {
	my $tmp= lc(substr($words[0],0,-1));
	if (exists $psh->{language}{$tmp}) {
	    eval 'use Psh2::Language::'.ucfirst($words[0]);
	    if ($@) {
		# TODO: Error handling
	    }
	    return [ 'language', 'Psh2::Language::'.ucfirst($words[0]), \@options, \@words, $line, $opt];
	} else {
	    die "parse: unsupported language $tmp";
	}
    }

    unless ($opt->{nobuiltin}) {
	if ($psh->is_builtin($words[0])) {
	    eval 'use Psh2::Builtins::'.ucfirst($words[0]);
	    if ($@) {
		# TODO: Error handling
	    }
	    return [ 'builtin', 'Psh2::Builtins::'.ucfirst($words[0]), \@options, \@words, $line, $opt];
	}
    }
    unless ($opt->{builtin}) {
	my $tmp= $psh->which($words[0]);
	if ($tmp) {
	    return [ 'execute', $tmp, \@options, \@words, $line, $opt];
	}
	foreach my $strategy (@{$psh->{strategy}}) {
	    my $tmp= eval {
		$strategy->applies(\@words, $line);
	    };
	    if ($@) {
		# TODO: Error handling
	    } elsif ($tmp) {
		return [ $strategy, $tmp, \@options, \@words, $line, $opt];
	    }
	}
    }
    die "duh";
}


1;
