package Psh::Joblist;

use strict;
require Psh::Job;

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;
	my @jobs_order= ();
	my %jobs_list= ();
	$self->{jobs_order}= \@jobs_order;
	$self->{jobs_list}= \%jobs_list;
	return $self;
}

sub create_job {
	my ($self, $pid, $call, $assoc_obj) = @_;
	my $jobs_order= $self->{jobs_order};
	my $jobs_list= $self->{jobs_list};

	my $job = new Psh::Job( $pid, $call, $assoc_obj);
	$jobs_list->{$pid}=$job;
	push(@$jobs_order,$job);
	return $job;
}

sub delete_job {
	my ($self, $pid) = @_;
	my $jobs_order= $self->{jobs_order};
	my $jobs_list= $self->{jobs_list};

	my $job= $jobs_list->{$pid};
	return if !defined($job);

	delete $jobs_list->{$pid};
	my $i;
	for($i=0; $i <= $#$jobs_order; $i++) {
		last if( $jobs_order->[$i]==$job);
	}

	splice( @$jobs_order, $i, 1);
}

sub job_exists {
	my ($self, $pid) = @_;

	return exists($self->{jobs_list}->{$pid});
}

sub get_job {
	my ($self, $pid) = @_;

	return $self->{jobs_list}->{$pid};
}

sub get_job_number {
	my ($self, $pid) = @_;
	my $jobs_order= $self->{jobs_order};

	for( my $i=0; $i<=$#$jobs_order; $i++) {
		return $i+1 if( $jobs_order->[$i]->{pid}==$pid);
	}
	return -1;
}

#
# $pid=$joblist->find_job([$jobnumber])
# Finds either the job with the specified job number
# or the highest numbered not running job and returns
# the job or undef is none is found
#
sub find_job {
	my ($self, $job_to_start) = @_;
	my $jobs_order= $self->{jobs_order};

	return $jobs_order->[$job_to_start] if defined( $job_to_start);

	for (my $i = $#$jobs_order; $i >= 0; $i--) {
		my $job = $jobs_order->[$i];

		if(!$job->{running}) {
			return wantarray?($i,$job):$job;
		}
	}
	return undef;
}

sub find_last_with_name {
	my ($self, $name, $runningflag) = @_;
	$self->enumerate();
	my $index=0;
	while( my $job= $self->each) {
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
	my $self= shift;

	$self->{pointer}=0;
}

#
# Returns the next job
#
sub each {
	my $self= shift;
	my $jobs_order= $self->{jobs_order};
	if( $self->{pointer}<=$#$jobs_order) {
		return $jobs_order->[$self->{pointer}++];
	}
	return undef;
}


1;
__END__

=head1 NAME

Psh::Joblist - A data structure suitable for handling job lists like bash's

=head1 SYNOPSIS

  use Psh::Joblist;

  $joblist= new Psh::Joblist();

  $job = $joblist->create_job($pid,$displayed_command);

  $joblist->delete_job($pid);

  $job = $joblist->get_job($pid);

  $flag = $joblist->job_exists($pid);

  $index = $joblist->get_job_number($pid);

  $job = $joblist->find_job();
  $job = $joblist->find_job($index);

  $joblist->enumerate();
  while( $job=$joblist->each()) { ... }  

=head1 DESCRIPTION

Read the source ;-)

=head1 AUTHOR

Markus Peter (warp@spin.de)

=head1 SEE ALSO

Psh::Job(3)

=cut
