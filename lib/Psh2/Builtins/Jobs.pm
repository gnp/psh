package Psh2::Builtins::Jobs;

require Getopt::Std;

=item * C<jobs [-q] [-rs] [-p]>

List the currently running jobs.

Option B<-r> restricts the output to display only currently running jobs.
Option B<-s> will only show currently stopped jobs
Option B<-p> will show only the PIDs of the processes

With B<-q> no output will made and C<jobs> will only set the exit
status to true (there are jobs) or false (no jobs).

=cut

sub execute {
    my $psh= shift;
    local @ARGV = @{shift()};
    my $opt={};
    Getopt::Std::getopts('prsq',$opt);

    my @list= $psh->list_jobs();
    if ($opt->{'q'}) {
	if (@list) {
	    return 1;
	} else {
	    return 0;
	}
    }


    my $result = '';
    my $job;
    my $visindex=0;

    foreach my $job (@list) {
	my $pid      = $job->{pgrp_leader};
	my $command  = $job->{desc};
	$visindex++;

	next if $opt->{'r'} and !$job->{running};
	next if $opt->{'s'} and $job->{running};

	if ($opt->{'p'}) { # print pid's only
	    $result.= "$pid\n";
	} else {
	    $result .= "[$visindex] $pid $command";

	    if ($job->{running}) { $result .= "\n"; }
	    else                 { $result .= ' ('.$psh->gt('stopped').")\n"; }
	}
    }

    if (!$result) {
	$psh->print($psh->gt('No jobs found.')."\n");
	return 0;
    }
    else {
	$psh->print($result);
	return 1;
    }
}

1;
