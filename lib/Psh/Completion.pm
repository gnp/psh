package Psh::Completion;

use strict;
use vars qw($VERSION);

use Cwd;
use Cwd 'chdir';

$VERSION = '0.02';

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
# Completes perl variables/
sub cmpl_perl
{
	my $text= shift;
	@completion_buffer=();

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
		push @completion_buffer, $rest
			if( length($tmp)>=length($text) &&
				substr($tmp,0,length($text)) eq $text);
	}
	return @completion_buffer;
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
	my (@tmp, $startchar, $starttext, $prevchar);

	$startchar= substr($line,$start,1);
	if( $start>0) { $prevchar= substr($line,$start-1,1) }
	else { $prevchar=''; }

	if ($startchar eq '~') {
		return $term->completion_matches($text,
			$attribs->{username_completion_function});
	} elsif( $prevchar eq "\$" || $prevchar eq "\@" || $prevchar eq "\&" ) {
		@tmp= &cmpl_perl($prevchar.$text);
		if($#tmp>-1) { return ($text,@tmp); }
		else { return undef; }
	} elsif( $startchar eq "\%") {
		# *sigh* $/@/& to not belong to a "readline word" but % does ?!?
		@tmp= &cmpl_perl($text);
		if($#tmp>-1) { return ($text,@tmp); }
		else { return undef; }		
	}

	#
	# Only return if executable match found something, otherwise try
	# filename completion
	# Only try executable completion if it's the first word or after | and
	# it does not contain .. or /

	$starttext= substr( $line, 0, $start);

	if ( ($starttext =~ /^\s*$/ ||
		  $starttext =~ /\|\s*$/ ) &&
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
