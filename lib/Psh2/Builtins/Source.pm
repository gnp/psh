package Psh2::Builtins::Source;

=item * C<source FILE> [or C<. FILE>]

Read and process the contents of the given file as a sequence of B<psh>
commands.

=cut

sub execute {
    my ($psh, $words)= @_;
    shift @$words;

    local $psh->{interactive}= 0;
    foreach my $file (@$words) {
	$psh->process_file($psh->abs_path($file));
    }
    return $psh->{status};
}

1;
