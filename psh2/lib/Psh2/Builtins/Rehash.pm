package Psh2::Builtins::Rehash;

=item * C<rehash>

Empties the path and executable hashes. This might be necessary if
executables are renamed/removed/added while you're logged in.

=cut

sub execute {
    my $psh= shift;
    $psh->{cache}{command}={};
    $psh->{cache}{path}={};
    return 1;
}

1;
