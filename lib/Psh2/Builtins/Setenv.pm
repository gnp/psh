package Psh2::Builtins::Setenv;

=item * C<setenv NAME [=] VALUE>

Sets the environment variable NAME to VALUE.

=cut

sub execute {
    my ($psh, $words)= @_;
    shift @$words;
    my $var= shift @$words;
    my $tmp= shift @$words;
    if ($tmp) {
	if ($tmp eq '=') {
	    $tmp= shift @$words;
	}
	$ENV{$var}= $tmp;
    } else {
	$psh->printerrln($psh->gt('setenv: setenv NAME not supported yet.'));
    }
    return (1,undef);
}


1;
