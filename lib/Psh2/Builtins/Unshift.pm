package Psh2::Builtins::Unshift;

=item * C<unshift variable values>

Push values onto the beginning of a variable

=cut

sub execute {
    my ($psh, $words)= @_;
    shift @$words;
    my $var= shift @$words;
    $var= $psh->get_variable($var);

    while (@$words) {
        unshift @{$var->{value}}, shift @$words;
    }
    $var->value_changed();
    return 1;
}

1;
