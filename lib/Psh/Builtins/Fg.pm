package Psh::Builtins::Fg;

require Psh::Util;
require Psh::Joblist;
require Psh;

=item * C<fg [%JOB|COMMAND]>

Bring a job into the foreground. If JOB is omitted, uses the
highest-numbered stopped job, or, failing that, the highest-numbered job.
JOB may either be a job number or a command. If you specify a command
it will launch a new program (this is for consisteny with the bg command)

=cut

sub bi_fg
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

	Psh::OS::restart_job(1, $arg );

	return (1,undef);
}

1;
