package Psh::Builtins::Bg;

require Psh::Util;
require Psh::Joblist;

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
		Psh::Util::print_error_i18n('no_jobcontrol');
		return (0,undef);
	}

	if (!defined($arg) || $arg eq '') {
		($arg)= Psh::Joblist::find_job();
	} else {
		if( $arg !~ /^\%/) {
			return Psh::evl($arg.' &');
		}
		$arg =~ s/\%//;

		if ( $arg !~ /^\d+$/) {
			($arg)= Psh::Joblist::find_last_with_name($arg,0);
		}
		$arg-- if defined($arg);
	}
	return (0,undef) unless defined($arg);

	Psh::OS::restart_job(0, $arg);

	return (1,undef);
}

1;
