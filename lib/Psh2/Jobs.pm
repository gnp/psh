package Psh2::Jobs;

use strict;
require POSIX;

my @order= ();
my %list= ();

sub start_job {
    my $array= shift;
    my $fgflag= shift @$array;

    my $visline= '';
    my ($read, $chainout, $chainin, $pgrp_leader);
    my $tmplen= @$array- 1;
    my @pids= ();
    my $success;
    for (my $i=0; $i<@$array; $i++) {
	# [ $strategy, $how, $options, $words, $line, $opt ]
	my ($strategy, $how, $options, $words, $text, $opt)= @{$array->[$i]};

	my $fork= 0;
	if ($i<$tmplen or !$fgflag or
	   ($strategy ne 'builtin' and
	    ($strategy ne 'language' or !$how->internal()))) {
	    $fork= 1;
	}

	if ($tmplen) {
	    ($read, $chainout)= POSIX::pipe();
	}
	foreach (@$options) {
	    if ($_->[0] == Psh2::Parser::T_REDIRECT and
	        ($_->[1] eq '<&' or $_->[1] eq '>&')) {
		if ($_->[3] eq 'chainin') {
		    $_->[3]= $chainin;
		} elsif ($_->[3] eq 'chainout') {
		    $_->[3]= $chainout;
		}
	    }
	}
	my $termflag= !($i==$tmplen);
	my $pid= 0;
	if ($^O eq 'MSWin32') {
	} else {
	    if ($fork) {
		($pid)= Psh2::Unix::fork($array->[$i], $pgrp_leader, $fgflag,
					 $termflag);
	    } else {
		($success)= Psh2::Unix::execute($array->[$i]);
	    }
	}
	if (!$i and !$pgrp_leader and $pid) {
	    $pgrp_leader= $pid;
	}
	if ($i<$tmplen and $tmplen) {
	    POSIX::close($chainout);
	    $chainin= $read;
	}
	$visline.='|' if $i>0;
	$visline.= $text;
	push @pids, $pid;
    }
    if (@pids) {
	my $job;
	if ($^O eq 'MSWin32') {
	} else {
	    $job= new Psh2::Unix::Job( pgrp_leader => $pgrp_leader,
				       pids => \@pids);
	    if ($fgflag) {
		$success= $job->wait_for_finish;
	    } else {
		# TODO: Diagnostic output
	    }
	}
    }
    return $success;
}

sub delete_job {
    my ($pid) = @_;

    my $job= $list{$pid};
    return unless defined $job;

    delete $list{$pid};
    my $i;
    for($i=0; $i <= $#order; $i++) {
	last if( $order[$i]==$job);
    }

    splice( @order, $i, 1);
}

sub job_exists {
    my $pid= shift;
    return exists $list{$pid};
}

sub get_job {
    my $pid= shift;
    return $list{$pid};
}

sub list_jobs {
    return wantarray?@order:\@order;
}

sub find_job {
    my $job_to_start= shift;

    return $order[$job_to_start] if defined( $job_to_start);

    for (my $i = $#order; $i >= 0; $i--) {
	my $job = $order[$i];
	if(!$job->{running}) {
	    return wantarray?($i,$job):$job;
	}
    }
    return undef;
}

package Psh2::Unix::Job;

sub new {
    my ($class, %self)= @_;
    my $self= \%self;
    die "missing pgrp leader" unless $self->{pgrp_leader};
    bless $self, $class;
    return $self;
}

sub resume {
    my $self= shift;
    kill 'CONT', -$self->{pgrp_leader};
}

sub wait_for_finish {
    my $self= shift;
    my $tmp= select(DEBUG); $|=1; select($tmp);

    my $psh_pgrp= CORE::getpgrp();
    my $pid_status= -1;
    my $status= 1;
    my @pids= @{$self->{pids}};
    my $term_pid= $self->{pgrp_leader} || $pids[$#pids];
    Psh2::Unix::_give_terminal_to($term_pid);
    my $returnpid;
    while (1) {
	if (!$self->{running}) {
	    $self->resume();
	}
	{
	    $returnpid= CORE::waitpid($pids[$#pids], POSIX::WUNTRACED());
	    $pid_status= $?;
	}
	last if $returnpid < 1;
	if ($returnpid == $pids[$#pids]) {
	    $status= POSIX::WEXITSTATUS($pid_status);
	    last;
	}
    }
    Psh2::Unix::_give_terminal_to($psh_pgrp);
    return $status==0;
}

1;
