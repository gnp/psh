package Psh2::Builtins::Echo;

=item * C<echo [-n] text>

Prints out the specified text. If B<-n> is specified, the trailing
newline is omitted.

=cut

sub execute {
    my ($psh, $words)= @_;
    shift @$words;
    my $newline= 1;
    if ($words->[0] eq '-n') {
	$newline= 0;
	shift @$words;
    }
    $psh->print(join(' ',@$words), $newline?"\n":'');
    return 1;
}

1;
