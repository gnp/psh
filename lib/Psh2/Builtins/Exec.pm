package Psh2::Builtins::Exec;

sub execute {
    my ($psh, $words)= @_;
    shift @$words;
    my $path= $psh->which($words->[0]);
    if ($path) {
	{ exec { $path } @$words; };
	$psh->printerr($psh->gt('psh: exec failed')."\n");
    } else {
	$psh->printerr(sprintf($psh->gt('psh: could not find %s'),
			      $words->[0])."\n");
    }
}

1;
