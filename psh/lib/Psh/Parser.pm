#! /usr/local/bin/perl -w
package Psh::Parser;

use strict;
use vars qw($VERSION);
use Carp;

use Psh::OS;

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

#
# array decompose(regexp DELIMITER, string LINE, int PIECES, 
#                 bool KEEP, hashref QUOTINGPAIRS, regexp METACHARACTERS
#                 scalarref UNMATCHED_QUOTE)
#
# decompose is a cross between split() and
# Text::ParseWords::parse_line: it breaks LINE into at most PIECES
# pieces separated by DELIMITER, except that the hash given by the
# reference QUOTINGPAIRS specifies pairs of quotes (each key is an
# open quote which matches the corresponding value) which prevent
# splitting on internal instances of DELIMITER, and negate the effect
# of other quotes. The quoting characters are retained if KEEP is
# true, discarded otherwise. Matches to the regexp METACHARACTERS
# (outside quotes) are their own words, regardless of being delimited.
# Backslashes escape the meanings of characters that might match
# delimiters, quotes, or metacharacters.  Initial unquoted empty
# pieces are suppressed. 

# The regexp DELIMITER may contain a single back-reference parenthesis
# construct, in which case the matches to the parenthesized
# subexpression are also placed among the pieces, as with the
# built-in split. METACHARACTERS may not contain any parenthesized
# subexpression.

# decompose returns the array of pieces. If UNMATCHED_QUOTE is
# specified, 1 will be placed in the scalar referred to if LINE
# contained an unmatched quote, 0 otherwise.

# If DELIMITER is undefined or equal to ' ', the regexp '\s+' is used
# to break on whitespace. If PIECES is undefined, as many pieces as
# necessary are used. KEEP defaults to 1. If QUOTINGPAIRS is
# undefined, {"'" => "'", "\"" => "\""} is used, i.e. single and
# double quotes are recognized. Supply a reference to an empty hash to
# have no quoting characters. METACHARACTERS defaults to a regexp that
# never matches.

# EXAMPLE: if $line is exactly

# echo fred(joe, "Happy Days", ' steve"jan ', "\"Oh, no!\"")

# then decompose(' ', $line) should break it at the
# following places marked by vertical bars: 

# echo|fred(joe,|"Happy Days",|' steve"jan',|"\"Oh, no!\"")

sub decompose 
{
    my ($delimexp,$line,$num,$keep,$quotehash,$metaexp,$unmatched) = @_;

    my $nevermatches = "(?!a)a"; # Anyone have other ideas?
    if (!defined($delimexp) or $delimexp eq ' ') { $delimexp = '\s+'; }
    if (!defined($num)) { $num = -1; }
    if (!defined($keep)) { $keep = 1; }
    if (!defined($quotehash)) { $quotehash = { "'" => "'", "\"" => "\"" }; }
    if (!defined($metaexp)) { $metaexp = $nevermatches; }

    # See if metacharacters has any parenthesized subexpressions:
    my @matches = ('x' =~ m/$metaexp|(.)/);
    if (scalar(@matches) > 1) { 
      carp "Metacharacter regexp '$metaexp' in decompose may not contain ().";
      return undef;
    }

    # Remember if delimexp came with any parenthesized subexpr, and
    # arrange for it to have exactly one so we know what each piece in
    # the match below means:

    my $saveDelimiters = 0;
    @matches = ('x' =~ m/$delimexp|(.)/);
    if (scalar(@matches) > 2) {
      carp "Delimiter regexp '$delimexp' in decompose may " .
	   "contain at most 1 ().";
      return undef;
    }
    if (scalar(@matches) == 2) {
      $saveDelimiters = 1;
    } else {
      $delimexp = "($delimexp)";
    }

    my @pieces = ('');
    my $startNewPiece = 0;
    my $freshPiece = 1;
    my $uquote = 0;

    my %qhash = %{$quotehash};
    #generate $quoteexp and fix up the closers:
    my $quoteexp = $nevermatches;
    for my $opener (keys %qhash) {
            $quoteexp .= '|' . quotemeta($opener);
	    $qhash{$opener} = quotemeta($qhash{$opener});
    }

    while ($line) {
            if ($startNewPiece) { 
	            push @pieces, '';
		    $startNewPiece = 0; 
		    $freshPiece = 1;
	    }
	    if (scalar(@pieces) == $num) { last; }
	    # $delimexp is unparenthesized below because we have
	    # already arranged for it to contain exactly one backref ()
            my ($prefix,$delimiter,$quote,$meta,$rest) =
	      ($line =~ m/^((?:[^\\]|\\.)*?)(?:$delimexp|($quoteexp)|($metaexp))(.*)$/s);
	    if (!$keep and defined($prefix)) {
	    	    # remove backslashes in unquoted part:
	            $prefix =~ s/\\(.)/$1/g;
	    }
	    if (defined($delimiter)) {
		    $pieces[scalar(@pieces)-1] .= $prefix;
		    if ($saveDelimiters) {
		            if ($pieces[scalar(@pieces)-1] or !$freshPiece) {
			            push @pieces, $delimiter;
		            } else {
			            $pieces[scalar(@pieces)-1] = $delimiter;
		            }
			    $startNewPiece = 1;
		    } elsif (scalar(@pieces) > 1 or $pieces[0]) {
		  	    $startNewPiece = 1;
		    }
		    $line = $rest;
	    } elsif (defined($quote)) {
		    my ($restOfQuote,$remainder) = 
		      ($rest =~ m/^((?:[^\\]|\\.)*?)$qhash{$quote}(.*)$/s);
		    if (defined($restOfQuote)) {
			    if ($keep) {
				    $pieces[scalar(@pieces)-1] .= "$prefix$quote$restOfQuote${$quotehash}{$quote}";
			    } else { #Not keeping, so remove backslash
                                     #from backslashed $quote occurrences
			            $restOfQuote =~ s/\\$quote/$quote/g;
				    $pieces[scalar(@pieces)-1] .= "$prefix$restOfQuote";
			    }
			    $line = $remainder;
			    $freshPiece = 0;
		    } else { # can't find matching quote, give up
		           $uquote = 1;
		           last;
		    }
	    } elsif (defined($meta)) {
                    $pieces[scalar(@pieces)-1] .= $prefix;
		    if ($pieces[scalar(@pieces)-1] or !$freshPiece) {
			    push @pieces, $meta;
		    } else { 
			    $pieces[scalar(@pieces)-1] = $meta;
		    }
		    $line = $rest;
		    $startNewPiece = 1;
	    } else { # nothing found, so remainder all one unquoted piece
	            if (!$keep and $line) {
	                      $line =~ s/\\(.)/$1/g;
		    }
		    last;
	    }
    }
    if ($line) { $pieces[scalar(@pieces)-1] .= $line; }
    if (defined($unmatched)) { ${$unmatched} = $uquote; }
    return @pieces;
}

#
# array std_tokenize(string LINE, [int PIECES])
#
# Wrapper for decompose, returns the "standard" psh tokenization of an
# (unmodified) line of psh input
#

sub std_tokenize 
{
    my ($line,$pieces) = @_;
    return decompose(' ',$line,$pieces,1,undef,'\&');
}

#
# int incomplete_expr(string LINE)
#
# Returns 2 if LINE has unmatched quotations. Returns -1 if LINE has
# mismatched parens. Otherwise, returns 1 if LINE has an unmatched
# open brace, parenthesis, or square bracket and 0 in all other
# cases. Summing up, negative is a mismatch, 0 is all OK, and positive
# is unfinished business. (Reasonably good, can be fooled with some
# effort. I therefore have deliberately not taken comments into
# account, which means you can use them to "unfool" this function, but
# also that unmatched stuff in comments WILL fool this function.)
#

my %perlq_hash = qw|' ' " " q( ) qw( ) qq( )|;

sub incomplete_expr
{
    my ($line) = @_;
    my $unmatch = 0;
    my @words = decompose(' ',$line,undef,1,\%perlq_hash,'[]{}()[]', \$unmatch);
    if ($unmatch) { return 2; }
    my @openstack = (':'); # : is used as a bottom marker here
    my %open_of_close = qw|) ( } { ] [|;
    foreach my $word (@words) {
            if ($word =~ m/^[{([]$/) { push @openstack, $word; }
            elsif ($word =~ m/^[])}]$/) {
	            my $open = $open_of_close{$word};
		    my $curopen = pop @openstack;
		    if ($open ne $curopen) {
		            return -1;
		    }
	    }
    }
    if (scalar(@openstack) > 1) { return 1; }
    return 0;
}

#
# glob_expansion()
#
# LINE EXPANSIONS:
#
# If we're going to be a shell, let's act like a shell. The idea here
# is to provide expansion functions that individual evaluation
# strategies can use on the argument list to perform operations
# similar to the ones a shell argument list undergoes. Each of these
# functions should take a reference to an array of "words" and return
# a solid (to be conservative, as opposed to modifying in place) array of
# "expanded words".
#
# Bash defines eight types of expansion in its manpage: brace
# expansion, tilde expansion, parameter and variable expansion,
# command substitution, arithmetic expansion, word splitting,
# pathname expansion, and process expansion.
#
# Of these, arithmetic expansion makes no sense in Perl. Word
# splitting should happen "on the fly", i.e., the array returned by
# one of these functions might have more elements than the argument
# did. Since the perl builtin "glob" handles brace, tilde and pathname
# expansion, here's a glob_expansion function that covers all of
# those. Also a variable_expansion function that handles substituting
# in the values of Perl variables. That leaves only:
#
# TODO: command_expansion (i.e., backticks. For this,
# backticks would have to be added to decompose as a recognized quote
# character), process_expansion
#
# TODO: should some of these line-processing actions happen in a
# uniform way, or should things simply be left to each evaluation strategy
# as psh currently works?
#
# array glob_expansion (arrayref WORDS)
#
# For each element x of the array referred to by WORDS, such that x
# is not quoted, push glob(x) onto an array, and return the collected array.
#

sub glob_expansion
{
	my ($arref) = @_;
	my @retval  = ();

	for my $word (@{$arref}) {
		if ($word =~ m/['"']/ # if it contains quotes
			or ($word !~ m/{.*}|\[.*\]|[*?]/)) { # or no globbing characters
			push @retval, $word;  # don't try to glob it
		} else { 
		        # Glob it. If anything happens, quote the
		        # results so they won't be clobbbered later.
		        my @results = Psh::OS::glob($word);
			if (scalar(@results) == 0) {
			         @results = ($word);
			} elsif (scalar(@results)>1 or $results[0] ne $word) {
			         foreach (@results) { $_ = "'$_'"; }
			}
			push @retval, @results;
		}
	}

	return @retval;
}


#
# bool needs_double_quotes (string WORD) 
#
# Returns true if WORD needs double quotes around it to be interpreted
# in a "shell-like" manner when passed to eval. This covers barewords,
# expressions that just have \-escapes and $variables in them, and
# filenames. 
#
# TODO: right now this is pretty much of a hack. Could it be improved?
#        For example, 'print hello \n' on the command line gets double
#        quotes around hello and \n, so that it ends up doing
#        print("hello","\n") which looks nice but is a surprise to
#        bash users. Perhaps backslash escapes simply shouldn't be OK?

sub needs_double_quotes
{
	my ($word) = @_;

	return if !defined($word) or !$word;

	if ($word =~ m/[a-zA-Z]/                     # if it has some letters
		and $word =~ m"^(\\.|[$.:a-zA-Z0-9/.])*$") { # and only these characters 
		return 1;                                # then double-quote it
	}

	return 0;
}




1;
__END__

=head1 NAME

Psh::Parser - bla

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 AUTHOR


=head1 SEE ALSO


=cut
