package Psh2::Builtins::Printf;

=item * C<printf format arguments>

Prints out the specified text with a format.

=cut

sub execute {
    my ($psh, $words)= @_;
    shift @$words;
    my $format= shift @$words;
    $psh->printf($format,@$words);
    return 1;
}


1;
