package Psh::Builtins::Jobs;

require Psh::Util;
require Psh::Joblist;
require Psh::OS;
require Getopt::Std;

=item * C<jobs [-rs] [-p]>

List the currently running jobs.

Option B<-r> restricts the output to display only currently running jobs.
Option B<-s> will only show currently stopped jobs

If you specify option B<-p> only the PIDs of the processes are displayed.

=cut

sub bi_jobs {
	my $line= shift;
	local @ARGV = @{shift()};

	if( ! Psh::OS::has_job_control()) {
		Psh::Util::print_error_i18n('no_jobcontrol');
		return (0,undef);
	}
	my $opt={};
	Getopt::Std::getopts('prs',$opt);

	my $result = '';
	my $job;
	my $visindex=0;

	Psh::Joblist::enumerate();

	while( ($job=Psh::Joblist::each())) {
		my $pid      = $job->{pid};
		my $command  = $job->{call};
		$visindex++;

		next if $opt->{'r'} and !$job->{running};
		next if $opt->{'s'} and $job->{running};

	    if ($opt->{'p'}) { # print pid's only
			$result.= "$pid\n";
		} else {
			$result .= "[$visindex] $pid $command";

			if ($job->{running}) { $result .= "\n"; }
			else                 { $result .= ' ('.Psh::Locale::get_text('stopped').")\n"; }
		}
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
