package Psh::Joblist;

use strict;
require Psh::OS;

my @jobs_order=();
my %jobs_list=();
my $pointer=0;

sub create_job {
	my ($pid, $call, $assoc_obj) = @_;

	my $job = new Psh::Job( $pid, $call, $assoc_obj);
	$jobs_list{$pid}=$job;
	push(@jobs_order,$job);
	return $job;
}

sub delete_job {
	my ($pid) = @_;

	my $job= $jobs_list{$pid};
	return if !defined($job);

	delete $jobs_list{$pid};
	my $i;
	for($i=0; $i <= $#jobs_order; $i++) {
		last if( $jobs_order[$i]==$job);
	}

	splice( @jobs_order, $i, 1);
}

sub job_exists {
	my $pid= shift;

	return exists($jobs_list{$pid});
}

sub get_job {
	my $pid= shift;
	return $jobs_list{$pid};
}

sub list_jobs {
	return @jobs_order;
}

sub get_job_number {
	my $pid= shift;

	for( my $i=0; $i<=$#jobs_order; $i++) {
		return $i+1 if( $jobs_order[$i]->{pid}==$pid);
	}
	return -1;
}

#
# $pid=Psh::Joblist::find_job([$jobnumber])
# Finds either the job with the specified job number
# or the highest numbered not running job and returns
# the job or undef is none is found
#
sub find_job {
	my $job_to_start= shift;

	return $jobs_order[$job_to_start] if defined( $job_to_start);

	for (my $i = $#jobs_order; $i >= 0; $i--) {
		my $job = $jobs_order[$i];

		if(!$job->{running}) {
			return wantarray?($i,$job):$job;
		}
	}
	return undef;
}

sub find_last_with_name {
	my ($name, $runningflag) = @_;
	enumerate();
	my $index=0;
	while( my $job= Psh::Joblist::each()) {
		next if $runningflag && $job->{running};
		my $call= $job->{call};
		if ($call=~ m:([^/\s]+)\s*: ) {
			$call= $1;
		} elsif( $call=~ m:/([^/\s]+)\s+.*$: ) {
			$call= $1;
		} elsif ( $call=~ m:^([^/\s]+): ) {
			$call= $1;
		}
		if( $call eq $name) {
			return wantarray?($index,$job->{pid},$job->{call}):$index;
		}
		$index++;
	}
	return wantarray?():undef;
}

#
# Resets the enumeration counter for access using "each"
#
sub enumerate {
	$pointer=0;
}

#
# Returns the next job
#
sub each {
	if ($pointer <= $#jobs_order) {
		return $jobs_order[$pointer++];
	}
	return undef;
}


package Psh::Job;

#
# $job= new Psh::Job( pid, call);
# Creates a new Job object
# pid is the pid of the object
# call is the name of the executed command
#
sub new {
	my ( $class, $pid, $call, $assoc_obj ) = @_;
	my $self = {};
	bless $self, $class;
	$self->{pid}=$pid;
	$self->{call}=$call;
	$self->{running}=1;
	$self->{assoc_obj}=$assoc_obj;
	return $self;
}

#
# $job->run;
# Sends SIGCONT to the job and records it running
#
sub continue {
	my $self= shift;

	# minus sign to wake up the whole group of the child:
	if( Psh::OS::has_job_control()) {
		Psh::OS::resume_job($self);
	}
	$self->{running}=1;
}

1;
__END__

=head1 NAME

Psh::Joblist - A data structure suitable for handling job lists like bash's

=head1 SYNOPSIS

  use Psh::Joblist;

  $job = Psh::Joblist::create_job($pid,$displayed_command);

  Psh::Joblist::delete_job($pid);

  $job = Psh::Joblist::get_job($pid);

  $flag = Psh::Joblist::job_exists($pid);

  $index = Psh::Joblist::get_job_number($pid);

  $job = Psh::Joblist::find_job();
  $job = Psh::Joblist::find_job($index);

  Psh::Joblist::enumerate();
  while( $job= Psh::Joblist::each()) { ... }

=head1 DESCRIPTION

Read the source ;-)

=head1 AUTHOR

Markus Peter (warp@spin.de)

=cut
