package Psh::Builtins::Bg;

use Psh::Util ':all';

=item * C<bg [%JOB|COMMAND]>

Put a job into the background. If JOB is omitted, uses the
highest-numbered stopped job, if any.

If you specify a command instead of a job id it will execute
the command in the background. You can use this if you do not
want to type "command &".

=cut

sub bi_bg
{
	my $arg = shift;

	if( ! Psh::OS::has_job_control()) {
		print_error_i18n('no_jobcontrol');
		return undef;
	}


	$arg = 0 if (!defined($arg) or ($arg eq ''));
	if( $arg !~ /^\%/) {
		Psh::evl($arg.' &');
		return undef;
	}
	$arg =~ s/\%//;

	if ( $arg !~ /^\d+$/) {
		$arg= $Psh::joblist->find_last_with_name($arg,0);
	}

	Psh::OS::restart_job(0, $arg - 1);

	return undef;
}

1;
