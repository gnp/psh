package Psh2::Builtins::Unalias;

=item * C<unalias NAME | -a | all]>

Removes the alias with name <C<I<NAME>> or all aliases if either <C<I<-a>>
(for bash compatibility) or <C<I<all>> is specified.

=cut

sub execute {
    my ($psh, $words)= @_;
    shift @$words;
    my $name= shift @$words;

    if( ($name eq '-a' || $name eq 'all')
	and !$psh->{aliases}{$name}) {
	$psh->{aliases}= {};
	return 1;
    } elsif ($psh->{aliases}{$name}) {
	delete $psh->{aliases}{$name};
	return 1;
    } else {
	$psh->printferrln($psh->gt('unalias: %s is no alias.'), $name);
	return 0;
    }
}

1;
