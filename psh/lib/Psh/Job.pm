#! /usr/local/bin/perl -w
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

	# minus sign to wake up the whole group of the child:
	kill 'CONT', -$self->{pid};
	$self->{running}=1;
}


1;
__END__

=head1 NAME

Psh::Job - Data structure representing a shell job

=head1 SYNOPSIS

  use Psh::Job;

  $joblist= new Psh::Joblist();

  $job= $joblist->create_job($pid, $command);

  $job->continue; # send SIGCONT to the job

  $job->{pid}; # to access the PID of the job
  $job->{call}; # to access the (command) name of the job
  $job->{running}; # to check wether the job is running

=head1 DESCRIPTION

This class is to be used in conjunction with Psh::Joblist

=head1 AUTHOR

Markus Peter, warp@spin.de

=head1 SEE ALSO

Psh::Joblist(3).

=cut
