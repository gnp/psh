package Psh::Parser;

use strict;
use vars qw($VERSION);

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

#
# array decompose(string LINE)
#
# decompose breaks LINE into pieces much like split(' ',LINE), except
# that single and double quotes prevent splitting on internal
# whitespace. It returns the array of pieces.  Thus, if LINE is
#    echo fred(joe, "Happy Days", ' steve"jan ', "\"Oh, no!\"")
# then decompose should break it at the following places marked by
# vertical bars:
#    echo|fred(joe,|"Happy Days",|' steve"jan',|"\"Oh, no!\"")
#
# As a special hack, if LINE ends in an ampersand followed by
# whitespace, the ampersand is split off into its own word.
#

sub decompose 
{
    my ($line) = @_;

    $line =~ s/^\s*//; # remove initial whitespace, shouldn't be in any piece

    my @pieces = ('');

    while ($line) {
		my ($prefix,$delimiter,$rest) =
			($line =~ m/^(\S*?)(\s+|(?<!\\)\"|(?<!\\)\')(.*)$/s);
		if (!defined($delimiter)) { # no delimiter found, so all one piece
			$pieces[scalar(@pieces)-1] .= $line;
			$line = '';
		} elsif ($delimiter =~ m/\s+/) {
			$pieces[scalar(@pieces)-1] .= $prefix;
			push @pieces, '';
			$line = $rest;
		} else { # $delimiter is " or '
			my ($restOfQuote,$remainder) = 
				($rest =~ m/^(.*?(?<!\\)$delimiter)(.*)$/s);
			if (defined($restOfQuote)) {
				$pieces[scalar(@pieces)-1] .= "$prefix$delimiter$restOfQuote";
				$line = $remainder;
			} else { # can't find matching delimiter
				$pieces[scalar(@pieces)-1] .= $line;
				$line = '';
			}
		} 
	}
    my $lastpiece = pop @pieces;
    if ($lastpiece =~ m/^(.*)\&\s*$/) {
		if ($1) { push @pieces, $1; }
		push @pieces, '&';
    } else { push @pieces, $lastpiece; }
    return @pieces;
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
			push @retval, glob($word); 
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
#        bash users. Perhaps backslash simply shouldn't be in the list
#        of OK characters?

sub needs_double_quotes
{
	my ($word) = @_;

	return if !defined($word) or !$word;

	if ($word =~ m/[a-zA-Z]/                     # if it has some letters
		and $word =~ m|^[$.:a-zA-Z0-9/.\\]*$|) { # and only these characters 
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
