package Psh::Completion;

use strict;
use vars qw($VERSION);

use Cwd;
use Cwd 'chdir';

$VERSION = '0.01';

my $term;
my $absed_path;

my @completion_buffer      = ();

sub init
{
	($term, $absed_path) = @_;
}

#
# Tries to find executables for possible completions
# TODO: This is sloooow... but probably not only because
# of searching the whole path but also because of the way
# Term::ReadLine::Gnu works... hmm
#

sub cmpl_executable
{
	my ($cmd, $state) = @_;

	if (!$state)
	{
		my $old_cwd        = cwd;
		@completion_buffer = ();

		my $tmp = psh::which($cmd);
		push( @completion_buffer, $tmp) if defined($tmp);
		# set up absed_path if not already set and check
		# wether we found an executable with exactly that name

		foreach my $dir (@$absed_path) {
			chdir psh::abs_path($dir);
			push( @completion_buffer, grep { -x && ! -d } glob "$cmd*" );
		}

		chdir $old_cwd;
	}

	return shift @completion_buffer;
}


#
# custom_completion()
#
# Main completion hook
#

sub custom_completion
{
	my ($text, $line, $start, $end) = @_;
	my $attribs                     = $term->Attribs;
	my @tmp;

	if (substr($line, $start, 1) eq "~") {
		return $term->completion_matches($text,
			$attribs->{username_completion_function});
	}

	#
	# Only return if executable match found something, otherwise try
	# filename completion
	# Only try executable completion if it's the first word or after | and
	# it does not contain .. or /

	my $start_text= substr( $line, 0, $start);

	if ( ($start_text =~ /^\s*$/ ||
		  $start_text =~ /\|\s*$/ ) &&
		!( $text =~ /\/|\.\.@/)) {
		@tmp = $term->completion_matches($text, \&cmpl_executable);
		return @tmp if defined @tmp;
	}

	return $term->completion_matches($text,
		   $attribs->{filename_completion_function});
}



1;
__END__

=head1 NAME

Psh::Completion - containing the completion routines of psh

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 AUTHOR

Markus Peter, warp@spin.de

=head1 SEE ALSO


=cut
