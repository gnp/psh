package Psh::Builtins::Jobs;

require Psh::Util;
require Psh::Joblist;
require Psh::OS;

=item * C<jobs>

List the currently running jobs.

=cut

sub bi_jobs {
	if( ! Psh::OS::has_job_control()) {
		Psh::Util::print_error_i18n('no_jobcontrol');
		return (0,undef);
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
		else                 { $result .= ' ('.Psh::Locale::get_text('stopped').")\n"; }
		$visindex++;
	}

	if (!$result) {
		Psh::Util::print_out_i18n('bi_jobs_none');
		return (0,undef);
	}
	else {
		Psh::Util::print_out($result);
		return (1,undef);
	}
}

1;
