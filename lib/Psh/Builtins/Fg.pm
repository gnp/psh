package Psh::Builtins::Fg;

use Psh::Util ':all';

=item * C<fg JOB>

Bring a job into the foreground. If JOB is omitted, uses the
highest-numbered stopped job, or, failing that, the highest-numbered job.
JOB may either be a job number or a word that occurs in the command used to create the job.

=cut

sub bi_fg
{
	my $arg = shift;

	if( ! Psh::OS::has_job_control()) {
		print_error_i18n('no_jobcontrol');
		return undef;
	}

	$arg = -0 if (!defined($arg) or ($arg eq ''));
	$arg =~ s/\%//;
	if( $arg =~ /[^0-9]/) {
		Psh::evl($arg);
		return undef;
	}

	Psh::OS::restart_job(1, $arg - 1);

	return undef;
}

1;
