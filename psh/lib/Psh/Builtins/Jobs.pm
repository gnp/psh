package Psh::Builtins::Jobs;

use Psh::Util ':all';

=item * C<jobs>

List the currently running jobs.

=cut

sub bi_jobs {
	if( ! Psh::OS::has_job_control()) {
		print_error_i18n('no_jobcontrol');
		return undef;
	}


	my $result = '';
	my $job;
	my $visindex=1;

	Psh::Joblist::enumerate();

	while( ($job=Psh::Joblist::each())) {
		my $pid      = $job->{pid};
		my $command  = $job->{call};
	    
		$result .= "[$visindex] $pid $command";

		if ($job->{running}) { $result .= "\n"; }
		else                 { $result .= ' ('.$Psh::text{stopped}.")\n"; }
		$visindex++;
	}

	if (!$result) { print_out_i18n('bi_jobs_none'); }
	else {
		print_out($result);
	}

	return undef;
}

1;
