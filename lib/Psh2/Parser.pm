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

my $part1= '(\\s+|\\|\\||\\&\\&|\||=>|->|;;|;|\\&|>>|>|<<|<|\\(|\\)|\\{|\\}|\\[|\\])';
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

sub make_tokens {
    my $line= shift;
    my (@parts, $openquotes)= decompose($line);
    die "parse: openquotes: $openquotes" if $openquotes;

    @parts= @{recombine_parts(\@parts)};

}

sub parse_line {
    my $line= shift;

    return () if substr( $line, 0, 1) eq '#';

    my @tokens= make_tokens( $line );
    while ( @tokens > 0 ) {

    }
}

1;
