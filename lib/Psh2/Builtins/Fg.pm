package Psh2::Builtins::Fg;

=item * C<fg [%JOB|COMMAND]>

Bring a job into the foreground. If JOB is omitted, uses the
current job.

JOB may either be a job number or a command. If you specify a command
it will launch a new program (this is for consisteny with the bg command)

=cut

sub execute
{
    my ($psh, $words)= @_;
    my $arg= $words->[1]||'';
    if (!$arg) {
	($arg)= $psh->get_current_job();
    } else {
	if( $arg !~ /^\%/) {
	    return $psh->process_variable($arg.' &');
	}
	$arg =~ s/\%//;
	if ( $arg !~ /^\d+$/) {
	    ($arg)= $psh->find_last_with_name($arg,0);
	} else {
	    $arg= $psh->find_job($arg-1);
	}
    }
    if (defined $arg) {
	$arg->restart(1);
    } else {
	$psh->printerr($psh->gt('fg: no such job')."\n");
	return 0;
    }
    return 1;
}

1;
