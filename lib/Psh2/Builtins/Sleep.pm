package Psh2::Builtins::Sleep;

=item * C<sleep n>

Sleeps the specified amount of seconds. It also supports fractional
seconds.

=cut

sub execute {
    my ($psh, $words)= @_;
    my $num= $words->[1]||1;
    select(undef, undef, undef, $num);
    return 1;
}

1;
