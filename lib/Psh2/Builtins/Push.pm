package Psh2::Builtins::Push;

=item * C<push variable values>

Push values onto the end of a variable

=cut

sub execute {
    my ($psh, $words)= @_;
    shift @$words;
    my $var= shift @$words;
    $var= $psh->get_variable($var);

    while (@$words) {
        push @{$var->{value}}, shift @$words;
    }
    $var->value_changed();
    return 1;
}

1;
