package Psh2::Builtins::Printenv;

=item * C<printenv NAME [NAME ...]>

Displays the named environment variables

=cut

sub execute {
    my ($psh, $words)= @_;
    my @names= @{$words};
    shift @names;
    if (@names) {
	foreach (@names) {
	    $psh->println($ENV{uc($_)});
	}
    } else {
	while (my ($key,$val)= each %ENV) {
	    $psh->println("$key=$val");
	}
    }
    return 1;
}

1;
