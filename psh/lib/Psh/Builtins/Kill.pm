package Psh::Builtins::Kill;

use Config ();


=item * C<kill [-SIGNAL] [%JOB | PID | JOBNAME] | -l>

Send SIGNAL (which defaults to TERM) to the given process, specified
either as a job (%NN) or as a pid (a number).

=cut

sub bi_kill
{
	if( ! Psh::OS::has_job_control()) {
		Psh::Util::print_error_i18n('no_jobcontrol');
		return undef;
	}

	my @args = split(' ',$_[0]);
	my $sig= 'TERM';
	my (@pids, $job);

	if (scalar(@args) == 1 &&
		$args[0] eq '-l') {
		Psh::Util::print_out($Config::Config{sig_name}."\n");
		return undef;
	} elsif( substr($args[0],0,1) eq '-') {
		$sig= substr($args[0],1);
		shift @args;
	}

	my $status= 0;
	foreach my $pid (@args) {
		if ($pid =~ m|^%(\d+)$|) {
			my $temp = $1 - 1;
			
			$job= $Psh::joblist->find_job($temp);
			if( !defined($job)) {
				Psh::Util::print_error_i18n('bi_kill_no_such_job',$pid);
				$status=1;
				next;
			}
			
			$pid = $job->{pid};
		}

		my ($index,$rpid)= $Psh::joblist->find_last_with_name($pid);
		if( $rpid) {
			$pid=$rpid;
		} else {
			Psh::Util::print_error_i18n('bi_kill_no_such_job',$pid);
		}
		
		if ($pid =~ m/\D/) {
			Psh::Util::print_error_i18n('bi_kill_no_such_jobspec',$pid);
			$status=1;
			next;
		}
		
		if ($sig ne 'CONT' and $Psh::joblist->job_exists($pid)
			and !(($job=$Psh::joblist->get_job($pid))->{running})) {
			#Better wake up the process so it can respond to this signal
			$job->continue;
		}

		$sig=0 if $sig eq 'ZERO'; # stupid perl bug
		
		if (CORE::kill($sig, $pid) != 1) {
			Psh::Util::print_error_i18n('bi_kill_error_sig',$pid,$sig);
			$status=1;
			next;
		}
		
		if ($sig eq 'CONT' and $Psh::joblist->job_exists($pid)) {
			$Psh::joblist->get_job($pid)->{running}=1;
		}
	}
	return $status;
}

# Completion function for kill
sub cmpl_kill {
	my( $text, $pretext, $starttext) = @_;
	my @tmp= ();

	$Psh::joblist->enumerate;
	while( my $job= $Psh::joblist->each) {
		push @tmp, $job->{call};
	}

	if( split(' ',$starttext)<2) {
		push @tmp, map { '-'.$_} split(' ', $Config::Config{sig_name});
	}

	return (1,grep { Psh::Util::starts_with($_,$text) } 
	         @tmp);
}

1;
