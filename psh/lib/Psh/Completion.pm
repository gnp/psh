package Psh::Completion;

use strict;
use vars qw($VERSION);

use Cwd;
use Cwd 'chdir';

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

my $term;
my $absed_path;
my @user_completions;
my $APPEND="not_implemented";
my $EMPTY_AC='';
my $GNU=0;
my $ac; # character to append

sub init
{
	($term, $absed_path) = @_;

	@user_completions= ();

	# TODO: Portability ?
	setpwent;
	while( my ($name)= getpwent) {
		push(@user_completions,'~'.$name);
	}
	endpwent;

	# The following is ridiculous, but....
	if( $term->ReadLine eq "Term::ReadLine::Perl") {
		$APPEND='completer_terminator_character';
		$term->Attribs->{completer_word_break_characters}=
			$term->Attribs->{completer_word_break_characters}.="\$\%\@\~/";
	} elsif( $term->ReadLine eq "Term::ReadLine::Gnu") {
		$GNU=1;
		$APPEND='completion_append_character';
		$EMPTY_AC="\0";
	}

	# Wow, both ::Perl and ::Gnu understand it
	$term->Attribs->{special_prefixes}= "\$\%\@\~";

}


# Returns a list of possible file completions
sub cmpl_filenames
{
	my $text= shift;
	my @result= glob "$text*";
	$ac='/' if(@result==1 && -d $result[0]);
	foreach (@result) {
		/\/([^\/]*$)/;
		$_=$1;
	}
	return @result;
}


# Returns an array with possible username completions
sub cmpl_usernames
{
	my $text= shift;
	my @result= grep { starts_with($_,$text) } @user_completions;
	return @result;
}


#
# Tries to find executables for possible completions
# TODO: This is sloooow... but probably not only because
# of searching the whole path but also because of the way
# Term::ReadLine::Gnu works... hmm
#

sub cmpl_executable
{
	my $cmd= shift;
	my $old_cwd        = cwd;
	my @result = ();

	my $tmp = psh::which($cmd);
	push( @result, $tmp) if defined($tmp);
	# set up absed_path if not already set and check
	# wether we found an executable with exactly that name
	
	foreach my $dir (@$absed_path) {
		chdir psh::abs_path($dir);
		push( @result, grep { -x && ! -d } glob "$cmd*" );
	}
	
	chdir $old_cwd;
	return @result;
}


#
# Completes perl variables
#
# TODO: Also complete package variables and package names
#
sub cmpl_perl
{
	my $text= shift;
	my @result=();

	return () if ! $text=~ /^[$%&@][a-zA-Z0-9_]*$/go;

	my (@tmp, @sym);
	{
		no strict qw(refs);
		@sym = keys %{*{"main::"}};
	}
	
	for my $sym (sort @sym) {
		next unless $sym =~ m/^[a-zA-Z]/; # Skip some special variables
		next if     $sym =~ m/::$/;       # Skip all package hashes
		{
			no strict qw(refs);
			push @tmp, "\$$sym" if
				ref *{"main::$sym"}{SCALAR} eq 'SCALAR';
			push @tmp,  "\@$sym" if
				ref *{"main::$sym"}{ARRAY}  eq 'ARRAY';
			push @tmp,   "\%$sym" if
				ref *{"main::$sym"}{HASH}   eq 'HASH';
			push @tmp,   "\&$sym" if
				ref *{"main::$sym"}{CODE}   eq 'CODE';
		}
	}
	foreach my $tmp (@tmp) {
		my $firstchar=substr($tmp,0,1);
		my $rest=substr($tmp,1);

		# Hack Alert ;-)
		next if(! eval "defined(${firstchar}main::$rest)" &&
				$rest ne "ENV" && $rest ne "INC" && $rest ne "$SIG" &&
				$rest ne "ARGV" );
		push @result, $tmp if starts_with($tmp,$text);
	}
	$ac=$EMPTY_AC if @result;
	return @result;
}

#
# custom_completion(text,line,start,end)
#
# Main Completion function
#

sub custom_completion
{
	my ($text, $line, $start) = @_;
	my $attribs               = $term->Attribs;
	my (@tmp, $startchar, $starttext);

	$startchar= substr($line, $start, 1);
	$starttext= substr($line, 0, $start);

	$ac=' ';

	if ($startchar eq '~' &&
	    !($text=~/\//)) {
		# after ~ try username completion
		@tmp= cmpl_usernames($text);
		$ac="/" if @tmp;
	} elsif( $startchar eq "\$" || $startchar eq "\@" || $startchar eq "\&" ||
			 $startchar eq "\%" ) {
		# probably a perl variable ?
		@tmp= cmpl_perl($text);
	} elsif( ($starttext =~ /^\s*$/ ||
			  $starttext =~ /[\|\`]\s*$/ ) &&
			 !( $text =~ /\/|\.\.@/)) {
		# we have the first word in the line or a pipe sign/backtick in front
		# of the current item, so we try to complete executables
		@tmp= cmpl_executable($text);
	} else {
		if( $GNU) { # faster....
			@tmp= $term->completion_matches($text,
						   $attribs->{filename_completion_function});
			shift @tmp if @tmp>1;
		}
		else
		{
			$starttext =~ /\s(\S*)$/;
			@tmp= cmpl_filenames($1.$text);
		}
	}

	$attribs->{$APPEND}=$ac;
	return @tmp;
}

#
# starts_with( completion, text)
# Called with the possible completion and the text to complete
# will return true if match

sub starts_with {
	my ($completion, $text) = @_;

	return length($completion)>=length($text) &&
		substr($completion,0,length($text)) eq $text;
}

1;
__END__

=head1 NAME

Psh::Completion - containing the completion routines of psh.
Currently works with Term::ReadLine::Gnu and Term::ReadLine::Psh

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 AUTHOR

Markus Peter, warp@spin.de

=head1 SEE ALSO


=cut
