package Psh::Job;

use strict;
use vars qw($VERSION);

$VERSION = '0.01';

#
# $job= new Psh::Job( pid, call);
# Creates a new Job object
# pid is the pid of the object
# call is the name of the executed command
#
sub new {
	my ( $class, $pid, $call ) = @_;
	my $self = {};
	bless $self, $class;
	$self->{pid}=$pid;
	$self->{call}=$call;
	$self->{running}=1;
	return $self;
}

#
# $job->run;
# Sends SIGCONT to the job and records it running
#
sub continue {
	my $self= shift;

	kill 'CONT', $self->{pid};
	$self->{running}=1;
}


1;
__END__

=head1 NAME

Psh::Job - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Psh::Job;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Psh::Job was created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head1 AUTHOR

A. U. Thor, a.u.thor@a.galaxy.far.far.away

=head1 SEE ALSO

perl(1).

=cut
