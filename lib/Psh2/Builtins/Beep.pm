package Psh2::Builtins::Beep;

=item * C<beep> [n]

Beeps (by sending a ^G to your terminal) once (or the specified number
of times).

This is e.g. useful to get a notification after a long running process
finished:

  C<make && beep 2>

=cut

sub execute {
    my ($psh, $words)= @_;
    my $num= 1;
    if ($words->[1]=~/^\d+$/) {
        $num= $words->[1];
    }
    $psh->printf('%c',7);
    if ($num>1) {
        for (my $i=1;$i<$num; $i++) {
            select(undef, undef, undef, 0.5);
            $psh->printf('%c',7);
        }
    }
    return 1;
}

1;
