package Psh2::Builtins::Bg;

=item * C<bg [%JOB|COMMAND]>

Put a job into the background. If JOB is omitted, uses the
current job.

If you specify a command instead of a job id it will execute
the command in the background. You can use this if you do not
want to type "command &".

=cut

sub execute {
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
	$arg->restart(0);
    } else {
	$psh->printerr($psh->gt('bg: no such job')."\n");
    }
}

1;
