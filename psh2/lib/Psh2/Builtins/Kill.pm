package Psh2::Builtins::Kill;

=item * C<kill [-SIGNAL] [%JOB | PID | JOBNAME] | -l>

Send SIGNAL (which defaults to TERM) to the given process, specified
either as a job (%NN) or as a pid (a number).

=cut

sub execute {
    my ($psh, $words)= @_;
    shift @$words;
    my $sig= 'TERM';
    my (@pids, $job);

    unless (@$words) {
	require Psh2::Builtins::Help;
	Psh2::Builtins::Help::execute($psh,['help','kill']);
	return 0;
    }

    if (scalar(@$words) == 1 &&
	$words->[0] eq '-l') {
	require Config;
	$psh->println($Config::Config{sig_name});
	return 1;
    } elsif( substr($words->[0],0,1) eq '-') {
	$sig= substr($words->[0],1);
	shift @$words;
    }

    my $count= 0;
    foreach my $pid (@$words) {
	if ($pid =~ m|^%(\d+)$|) {
	    my $temp = $1 - 1;

	    $job= $psh->find_job($temp);
	    $job= Psh::Joblist::find_job($temp);
	    if( !defined($job)) {
		$psh->printferrln($psh->gt('kill: no such job %s'),$pid);
		next;
	    }

	    $pid = $job->{pid};
	}
	elsif ($pid !~ m/^\d+$/) {
	    $job= $psh->find_last_with_name($pid);
	    if( $job) {
		$pid= $job->{pid};
	    } else {
		$psh->printferrln($psh->gt('kill: no such job %s'), $pid);
		next;
	    }
	}

	if ($sig ne 'CONT' and $psh->job_exists($pid)
	    and !(($job= $job->get_job($pid))->{running})) {
	    #Better wake up the process so it can respond to this signal
	    $job->resume();
	}

	$sig=0 if $sig eq 'ZERO'; # stupid perl bug

	if (my $num=CORE::kill($sig, $pid) != 1) {
	    $psh->printferrln($psh->gt('kill: Error sending signal %s to process %s'),$sig, $pid);
	    next;
	} else {
	    $count+=$num;
	}

	if ($sig eq 'CONT' and $psh->job_exists($pid)) {
	    $psh->get_job($pid)->{running}=1;
	}
    }
    return $count!=0;
}

1;
