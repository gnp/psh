package Psh2::Builtins::Hash;

=item * C<hash>

Shows information about Psh's executable and path hashes.

=item * C<hash -r>

Empties the path and executable hashes. This might be necessary if
executables are renamed/removed/added while you're logged in.

=cut

sub execute {
    my ($psh, $words)= @_;
    shift @$words;

    if (@$words) {
	while (my $sub= shift @$words) {
	    if (substr($sub,0,1) eq '-') {
		if ($sub eq '-r') {
		    $psh->{cache}{command}={};
		    $psh->{cache}{path}={};
		} else {
		    $psh->printferrln($psh->gt("Unknown option: %s"),$sub);
		}
	    } else {
	    }
	}
    }
    else {
	while (my ($key,$val)= each %{$psh->{cache}{command}}) {
	    $val||='';
	    $psh->print("$key=$val\n");
	}
	while (my ($key,$val)= each %{$psh->{cache}{path}}) {
	    $psh->print("$key=$val\n");
	}
    }
    return 1;
}

1;
