package Psh::Builtins::Bg;

use Psh::Util ':all';

=item * C<bg [JOB]>

Put a job into the background. If JOB is omitted, uses the
highest-numbered stopped job, if any.

=cut

sub bi_bg
{
	my $arg = shift;

	if( ! Psh::OS::has_job_control()) {
		print_error_i18n('no_jobcontrol');
		return undef;
	}


	$arg = 0 if (!defined($arg) or ($arg eq ''));
	$arg =~ s/\%//;
	if( $arg =~ /[^0-9]/) {
		Psh::evl($arg.' &');
		return undef;
	}

	Psh::OS::restart_job(0, $arg - 1);

	return undef;
}

1;
