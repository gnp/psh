package Psh2::Builtins::Dirs;

=item * C<dirs> [n]

Prints out [the last n] entries in the cd history

=cut

sub execute {
    my ($psh, $words)= @_;
    my $max= @{$psh->{dirstack}}-1;

    if (@$words>1 and $words->[1]=~/^\d+$/) {
        $max=$words->[1]-1 if $words->[1]<=$max;
    }

    for (my $i=$max; $i>=0; $i--) {
        $psh->printf('%%%-2d ',$i);

        if ($i==$psh->{dirstack_pos}) {
            $psh->print(" > ");
        } else {
            $psh->print("   ");
        }
        $psh->println($psh->{dirstack}[$i]);
    }
    return 1;
}

1;
