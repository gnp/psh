package Psh2::Builtins::Exec;

=item * C<exec COMMAND>

Starts the specified command and replaces the shell with it.

=cut

sub execute {
    my ($psh, $words)= @_;
    shift @$words;
    my $path= $psh->which($words->[0]);
    if ($path) {
	{ exec { $path } @$words; };
	$psh->printerr($psh->gt('psh: exec failed')."\n");
	return 0;
    } else {
	$psh->printerr(sprintf($psh->gt('psh: could not find %s'),
			      $words->[0])."\n");
    }
    return 1;
}

1;
