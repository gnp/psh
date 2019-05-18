#! /usr/local/bin/perl -w
package Psh::Parser;

use strict;

require Psh::OS;
require Psh::Util;
require Psh::Strategy;

sub T_END() { 0; }
sub T_WORD() { 1; }
sub T_PIPE() { 2; }
sub T_REDIRECT() { 3; }
sub T_BACKGROUND() { 4; }
sub T_OR() { 5; }
sub T_AND() { 6; }

sub T_EXECUTE() { 1; }

# ugly, ugly, but makes things faster

my %quotehash = qw|' ' " " q( ) qw( ) qq( ) ` `|;
my %quotedquotes = ();
my $def_quoteexp;
my $def_tokenizer= '(\\s+|\\|\\||\\&\\&|\||=>|->|;;|;|\\&|>>|>|<<|<|\\(|\\)|\\{|\\}|\\[|\\])';
my $nevermatches = "(?!a)a";


$def_quoteexp = $nevermatches;
foreach my $opener (keys %quotehash) {
	$def_quoteexp .= '|' . quotemeta($opener);
	$quotedquotes{$opener} = quotemeta($quotehash{$opener});
}

my $stdallinall= "^((?:[^\\\\]|\\\\.)*?)(?:$def_tokenizer|($def_quoteexp))(.*)\$";

if ($]>=5.005) {
	eval {
		$stdallinall= qr{$stdallinall}s;
	};
}

sub decompose {
    my ($delimexp,$line,$num,$keep,$unmatched) = @_;
	my @matches;

    if (!defined($delimexp)) { $delimexp = $def_tokenizer; }
	elsif ($delimexp eq ' ') { $delimexp='(\s+)'; }

    if (!defined($num)) { $num = -1; }
    if (!defined($keep)) { $keep = 1; }

    # Remember if delimexp came with any parenthesized subexpr, and
    # arrange for it to have exactly one so we know what each piece in
    # the match below means:

    my $saveDelimiters = 0;
    @matches = ('x' =~ m/$delimexp|(.)/);
    if (@matches > 2) {
		require Carp;
		Carp::carp("Delimiter regexp '$delimexp' in decompose may " .
		  "contain at most 1 ().");
		return undef;
    }
    if (@matches == 2) {
      $saveDelimiters = 1;
    } else {
      $delimexp = "($delimexp)";
    }

	return _decompose($line, "^((?:[^\\\\]|\\\\.)*?)(?:$delimexp|($def_quoteexp))(.*)\$", $keep, $num, $unmatched, $saveDelimiters-1);
}

sub _decompose
{
	my ( $line, $regexp, $keep, $num, $unmatched, $saveDelimiters)= @_;

	$saveDelimiters++;
    my @pieces = ('');
    my $startNewPiece = 0;
    my $freshPiece = 1;
    my $uquote = 0;
    while ($line) {
		if ($startNewPiece) {
			push @pieces, '';
		    $startNewPiece = 0;
		    $freshPiece = 1;
	    }
	    if (@pieces == $num) { last; }

	    # $delimexp is unparenthesized below because we have
	    # already arranged for it to contain exactly one backref ()
		my ($prefix,$delimiter,$quote,$rest) =
	      ($line =~ m/$regexp/s);
	    if (!$keep and defined($prefix)) {
			$prefix= remove_backslash($prefix);
	    }
	    if (defined($delimiter)) {
		    $pieces[$#pieces] .= $prefix;
		    if ($saveDelimiters) {
				if (length($pieces[$#pieces]) or !$freshPiece) {
					push @pieces, $delimiter;
				} else {
					$pieces[$#pieces] = $delimiter;
				}
			    $startNewPiece = 1;
		    } elsif (@pieces > 1 or $pieces[0]) {
		  	    $startNewPiece = 1;
		    }
		    $line = $rest;
	    } elsif (defined($quote)) {
			my ($restOfQuote,$remainder) = 
			  ($rest =~ m/^((?:[^\\]|\\.)*?)$quotedquotes{$quote}(.*)$/s);
			if (defined($restOfQuote)) {
				if (!$keep and
				    $quote ne "\'" and $quote ne 'q(') {
					$restOfQuote= remove_backslash($restOfQuote);
				}
				$pieces[$#pieces]= join('',$pieces[$#pieces],$prefix,
										$quote,$restOfQuote,
										$quotehash{$quote});
				$line = $remainder;
				$freshPiece = 0;
			} else { # can't find matching quote, give up
				$uquote = 1;
				last;
			}
	    } else { # nothing found, so remainder all one unquoted piece
			if (!$keep and length($line)) {
				$line= remove_backslash($line);
		    }
		    last;
	    }
    }
    if (length($line)) { $pieces[$#pieces] .= $line; }
    if (defined($unmatched)) { ${$unmatched} = $uquote; }
    return wantarray?@pieces:\@pieces;
}

sub incomplete_expr
{
    my ($line) = @_;
	return 0 unless $line=~/[\[{('"]/s;

    my $unmatch = 0;
	my @words= 	@{scalar(_decompose($line,$stdallinall, 1, undef, \$unmatch))};
    if ($unmatch) { return 2; }

    my @openstack = (':'); # : is used as a bottom marker here
    my %open_of_close = qw|) ( } { ] [ " '|;

    foreach my $word (@words) {
		next if length($word)!=1;
		if ($word eq '[' or $word eq '{' or $word eq '(' or $word eq '"' or
		    $word eq "\"") {
			push @openstack, $word;
		} elsif ($word eq ')' or $word eq '}' or $word eq ']' or $word eq '"' or
				 $word eq "\"") {
			my $open= $open_of_close{$word};
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
	my $arref= shift;
	my $join_char= shift;
	my @retval  = ();

	for my $word (@{$arref}) {
		if ($word =~ m/['"']/ # if it contains quotes
			or ($word !~ m/{.*}|\[.*\]|[*?~]/)) { # or no globbing characters
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
			if( $join_char) {
				push @retval, join($join_char, @results);
			} else {
				push @retval, @results;
			}
		}
	}

	return @retval;
}

sub unquote {
	my $text= shift;

	if (substr($text,0,1) eq '\'' and
	    substr($text,-1,1) eq '\'') {
		$text= substr($text,1,-1);
	} elsif ( substr($text,0,1) eq "\"" and
			 substr($text,-1,1) eq "\"") {
		$text= substr($text,1,-1);
	} elsif (substr($text,0,1) eq "\\") {
		$text= substr($text,1);
	}
	return $text;
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
	#
	#$text=~ s/\\(.)/$1/g;
	#
	# this breaks constructs like:
	# > print "\\\\\n"
	# \
	# >
	# should be:
	# > print "\\\\\n"
	# \\
	# >
	#

	return $text;
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

sub parse_fileno {
	my $tmp= shift;
	my $default1= shift;
	my $default2= shift;
	
	my @tmp= split('=', $tmp);   # [out=in] - not supported fully yet
	if (@tmp>2) {
		return undef;
	}
	if (@tmp<2) {
		push @tmp, $default2;
	}
	if (@tmp==2 && !$tmp[0]) {
		$tmp[0]= $default1;
	}
	my @result=();
	foreach (@tmp) {
		no strict 'refs';
		if (lc($_) eq 'all') {
			$_=1;
		}
		if (/^\d+$/) {
			push @result, $_+0;
		} else {
			if (ref *{"$Psh::PerlEval::current_package\:\:$_"}{IO}) {
				push @result, fileno(*{"$Psh::PerlEval::current_package\:\:$_"});
			}
		}
	}
	return @result;
}

sub make_tokens {
	my $line= shift;
	my $splitonly= shift;
	my @tmpparts= @{scalar(_decompose($line,$stdallinall, 0))};
	return @tmpparts if $splitonly;

	# Walk through parts and combine parenthesized parts properly
	my @parts=();
	my $nestlevel=0;
	my @tmp=();
	foreach (@tmpparts) {
		if (length($_)==1) {
			if ($_ eq '[' or $_ eq '(' or $_ eq '{') {
				$nestlevel++;
			} elsif ($_ eq '}' or $_ eq ')' or $_ eq ']') {
				$nestlevel--;
			}
		}
		if ($nestlevel) {
			push @tmp, $_;
		} elsif (@tmp) {
			push @parts,join('',@tmp,$_);
			@tmp=();
		} else {
			push @parts, $_;
		}
	}

	my @tokens= ();
	my @t=();
	my $tmp;
	while( defined($tmp= shift @parts)) {
		if ($tmp eq '||' or $tmp eq '&&') {
			push @t, @tokens;
			push @t, [T_END],[$tmp eq '||'?T_OR:T_AND];
			@tokens=();
		}
		elsif ($tmp eq ';;') {
			push @tokens, [T_WORD,';'];
		}
		elsif( $tmp eq '|') {
			my @fileno=(1,0);
			if (@parts>0) {
				my $tmp= shift @parts;
				if ($tmp=~/^\[(.+?)\]$/) {
					my $tmp2= $1;
					if (lc($tmp2) eq 'all') {
						push @tokens, [T_REDIRECT, '>&', 2, 1];
					}
					@fileno= parse_fileno($tmp2,1,0);
					if (!@fileno) {
						print STDERR "Illegal syntax\n"; ## FIXME
						return undef;
					}
				} else {
					unshift @parts, $tmp;
				}
			}
			push @t, [T_REDIRECT, '>&', $fileno[0], 'chainout']; # needs to come first
			push @t, @tokens;
			push @t, [T_PIPE];
			@tokens=( [T_REDIRECT, '<&', $fileno[1], 'chainin']);
		} elsif( $tmp =~ /^(>>?)$/) {
			my $tmp= $1;

			my $file;
			my @fileno=(1,0);
			my $allflag=0;
			if (@parts>0) {
				my $tmp= shift @parts;
				if ($tmp=~/^\[(.+?)\]$/) {
					my $tmp2= $1;
					if (lc($tmp2) eq 'all') {
						$allflag=1;
					}
					@fileno= parse_fileno($tmp2,1,0);
					if (!@fileno) {
						print STDERR "Illegal syntax\n"; ## FIXME
						return undef;
					}
				} else {
					unshift @parts, $tmp;
				}
			}
			if ($fileno[1]==0) {
				while( @parts>0) {
					$file= shift @parts;
					last if( $file !~ /^\s+$/);
						$file='';
				}
				if( !$file or substr($file,0,1) eq '&') {
					Psh::Util::print_error_i18n('redirect_file_missing',
												$tmp,$Psh::bin);
					return undef;
				}
				push @tokens, [T_REDIRECT,$tmp,$fileno[0],unquote($file)];
				} else {
					push @tokens, [T_REDIRECT, '>&', @fileno];
				}
			if ($allflag) {
				push @tokens, [T_REDIRECT, '>&', 2, 1];
			}
		} elsif( $tmp eq '<') {
			my $file;
			my @fileno=(0,0);
			if (@parts>0) {
				my $tmp= shift @parts;
				if ($tmp=~/^\[(.+?)\]$/) {
					@fileno= parse_fileno($1,0,0);
					if (!@fileno) {
						print STDERR "Illegal syntax\n"; ## FIXME
						return undef;
					}
				}
				else {
					unshift @parts, $tmp;
				}
			}
			if ($fileno[0]==0) {
				while( @parts>0) {
					$file= shift @parts;
					last if( $file !~ /^\s+$/);
					$file='';
				}
				if( !$file or substr($file,0,1) eq '&') {
					Psh::Util::print_error_i18n('redirect_file_missing',
												$tmp,$Psh::bin);
					return undef;
				}
				push @tokens, [T_REDIRECT,'<',$fileno[1],unquote($file)];
			} else {
				push @tokens, [T_REDIRECT,'<&',$fileno[1],$fileno[0]];
			}
		} elsif( $tmp eq '&') {
			push @t, @tokens;
			push @t, [T_BACKGROUND],[T_END];
			@tokens=();
		} elsif( $tmp eq ';') {
			push @t, @tokens;
			push @t, [T_END];
			@tokens= ();
		} elsif ($tmp eq '`') {
			my $tmp='';
			while ( (my $tmp2= shift @parts) ne '`' ) {
				$tmp.=' '.$tmp2;
			}
			$tmp= Psh::OS::backtick($tmp);
			$tmp=~ s/\\/\\\\/g;
			$tmp=~ s/\"/\\\"/g;
			$tmp=~ s/\n/\\n/g;
			$tmp=~ s/\$/\\\$/g;
			$tmp=~ s/\@/\\\@/g;
			push @tokens, [T_WORD, join('','"', $tmp,'"')];
		} elsif( $tmp=~ /^\s+$/) {
		} else {
			push @tokens, [T_WORD,$tmp];
		}
	}
    push @t, @tokens;
	return @t;
}

sub parse_line {
	my $line= shift;
	my (@use_strats) = @_;

	return () if substr($line,0,1) eq '#';

	my ($lvl1,$lvl2,$lvl3);
	if (@use_strats) {
		($lvl1,$lvl2,$lvl3)= Psh::Strategy::parser_return_objects(@use_strats);
	} elsif (@Psh::temp_use_strats) {
		($lvl1,$lvl2,$lvl3)= Psh::Strategy::parser_return_objects(@Psh::temp_use_strats);
	} else {
		($lvl1,$lvl2,$lvl3)= Psh::Strategy::parser_strategy_list();
	}

	if (@$lvl1) {
		foreach my $strategy (@$lvl1) {
			my $how= eval {
				$strategy->applies(\$line);
			};
			if ($@) {
				print STDERR $@;
			} elsif ($how) {
				my $name= $strategy->name;
				Psh::Util::print_debug_class('s',
											 "[Using strategy $name: $how]\n");
				return ([ T_EXECUTE, 1, [$strategy, $how, [], [$line], $line ]]);
			}
		}
	}
	if (@$lvl2) {
		die "Level 2 Strategies currently not supported!";
	}
	if (@$lvl3) {
		my @tokens= make_tokens( $line);
		my @elements=();
		my $element;
		while( @tokens > 0) {
			$element=parse_complex_command(\@tokens,$lvl3);
			return undef if ! defined( $element); # TODO: Error handling
			push @elements, $element;
			if (@tokens > 0) {
				if ($tokens[0][0] == T_END) {
					shift @tokens;
				}
				if (@tokens > 0) {
					if ($tokens[0][0] == T_AND) {
						shift @tokens;
						push @elements, [ T_AND ];
					} elsif ($tokens[0][0] == T_OR) {
						shift @tokens;
						push @elements, [ T_OR ];
					}
				}
			}
		}
		return @elements;
	}
}

sub parse_complex_command {
	my $tokens= shift;
	my $strategies= shift;
	my $piped= 0;
	my $foreground = 1;
	return [ T_EXECUTE, $foreground, _subparse_complex_command($tokens,$strategies,\$piped,\$foreground,{})];
}

sub _subparse_complex_command {
	my ($tokens,$use_strats,$piped,$foreground,$alias_disabled)=@_;
	my @simplecommands= parse_simple_command($tokens,$use_strats, $piped,$alias_disabled,$foreground);

	while (@$tokens > 0 && $tokens->[0][0] == T_PIPE) {
		shift @$tokens;
		$$piped= 1;
		push @simplecommands, parse_simple_command($tokens,$use_strats,$piped,$alias_disabled,$foreground);
	}

	if (@$tokens > 0 && $tokens->[0][0] == T_BACKGROUND) {
		shift @$tokens;
		$$foreground = 0;
	}
	return @simplecommands;
}

sub parse_simple_command {
	my ($tokens,$use_strats,$piped,$alias_disabled,$foreground)=@_;
	my (@words,@options,@savetokens,@precom);
	my $opt={};

	my $firstwords=1;
	while (@$tokens > 0 and
		   ($tokens->[0][0] == T_WORD or
			$tokens->[0][0] == T_REDIRECT)) {
		my $token = shift @$tokens;
		if ($token->[0] == T_WORD) {
			if ($firstwords and
			    ($token->[1] eq 'noglob' or
				 $token->[1] eq 'noexpand' or
				 $token->[1] eq 'noalias')) {
				push @precom, $token;
				$opt->{$token->[1]}=1;
			} else {
				$firstwords=0;
				push @savetokens,$token;
				push @words, $token->[1];
			}
		} elsif ($token->[0] == T_REDIRECT) {
			push @options, $token;
		} else {
		}
	}

	if (%Psh::Support::Alias::aliases and
		!$opt->{noalias} and
	    $Psh::Support::Alias::aliases{$words[0]} and
	    !$alias_disabled->{$words[0]}) {
		my $alias= $Psh::Support::Alias::aliases{$words[0]};
		$alias =~ s/\'/\\\'/g;
		$alias_disabled->{$words[0]}=1;
		my @tmp= make_tokens($alias);
		unshift @tmp, @precom;
		shift @savetokens;
		push @tmp, @savetokens;
		push @tmp, @options;
		return _subparse_complex_command(\@tmp,$use_strats,$piped,$foreground,$alias_disabled);
	} elsif (substr($words[0],0,1) eq "\\") {
		$words[0]=substr($words[0],1);
	}

	my $line= join ' ', @words;
	local $Psh::current_options= $opt;
	foreach my $strat (@$use_strats) {
		my $how= eval {
			$strat->applies(\$line,\@words,$$piped);
		};
		if ($@) {
			print STDERR $@;
		}
		elsif ($how) {
			my $name= $strat->name;
			Psh::Util::print_debug_class('s',
										 "[Using strategy $name: $how]\n");
			return [ $strat, $how, \@options, \@words, $line, $opt];
		}
	}
	Psh::Util::print_error_i18n('clueless',$line,$Psh::bin);
	die '';
}

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
		and $word =~ m!^(\\.|[$.:a-zA-Z0-9/.])*$!) { # and only these characters 
		return 1;                                # then double-quote it
	}

	return 0;
}




1;
__END__

=head1 NAME

  Psh::Parser - Perl Shell Parser

=head1 SYNOPSIS

  use Psh::Parser;

=head1 DESCRIPTION

=over 4

=item *

  array decompose(regexp DELIMITER, string LINE, int PIECES,
                  bool KEEP, hashref QUOTINGPAIRS,
                  scalarref UNMATCHED_QUOTE)

decompose is a cross between split() and
Text::ParseWords::parse_line: it breaks LINE into at most PIECES
pieces separated by DELIMITER, except that the hash given by the
reference QUOTINGPAIRS specifies pairs of quotes (each key is an
open quote which matches the corresponding value) which prevent
splitting on internal instances of DELIMITER, and negate the effect
of other quotes. The quoting characters are retained if KEEP is
true, discarded otherwise. Matches to the regexp METACHARACTERS
(outside quotes) are their own words, regardless of being delimited.
Backslashes escape the meanings of characters that might match
delimiters, quotes, or metacharacters.  Initial unquoted empty
pieces are suppressed. 

The regexp DELIMITER may contain a single back-reference parenthesis
construct, in which case the matches to the parenthesized
subexpression are also placed among the pieces, as with the
built-in split. METACHARACTERS may not contain any parenthesized
subexpression.

decompose returns the array of pieces. If UNMATCHED_QUOTE is
specified, 1 will be placed in the scalar referred to if LINE
contained an unmatched quote, 0 otherwise.

If PIECES is undefined, as many pieces as
necessary are used. KEEP defaults to 1. If QUOTINGPAIRS is
undefined, {"'" => "'", "\"" => "\""} is used, i.e. single and
double quotes are recognized. Supply a reference to an empty hash to
have no quoting characters. METACHARACTERS defaults to a regexp that
never matches.

EXAMPLE: if $line is exactly

echo fred(joe, "Happy Days", ' steve"jan ', "\"Oh, no!\"")

then decompose(' ', $line) should break it at the
following places marked by vertical bars: 

echo|fred(joe,|"Happy Days",|' steve"jan',|"\"Oh, no!\"")

=item *

  int incomplete_expr(string LINE)

Returns 2 if LINE has unmatched quotations. Returns -1 if LINE has
mismatched parens. Otherwise, returns 1 if LINE has an unmatched
open brace, parenthesis, or square bracket and 0 in all other
cases. Summing up, negative is a mismatch, 0 is all OK, and positive
is unfinished business. (Reasonably good, can be fooled with some
effort. I therefore have deliberately not taken comments into
account, which means you can use them to "unfool" this function, but
also that unmatched stuff in comments WILL fool this function.)

=item *

  string unquote( string word)

Removes quotes from a word and backslash escapes

=item *

  bool needs_double_quotes (string WORD)

Returns true if WORD needs double quotes around it to be interpreted
in a "shell-like" manner when passed to eval. This covers barewords,
expressions that just have \-escapes and $variables in them, and
filenames.

=back

=head1 AUTHOR

Various

=cut
