package Psh2::Builtins::Alias;

=item * C<alias [NAME [=] REPLACEMENT]> 

Add C<I<NAME>> as a built-in so that NAME <REST_OF_LINE> will execute
exactly as if REPLACEMENT <REST_OF_LINE> had been entered. For
example, one can execute C<alias ls ls -F> to always supply the B<-F>
option to "ls". Note the built-in is defined to avoid recursion
here.

With no arguments, prints out a list of the current aliases.
With only the C<I<NAME>> argument, prints out a definition of the
alias with that name.

=cut

sub execute
{
    my ($psh, $words)= @_;
    shift @$words;
    if (!@$words) {
	my @order= sort { lc($a) cmp lc($b) } keys %{$psh->{aliases}};
	foreach my $key (@order) {
	    my $tmp= $psh->{aliases}{$key};
	    $psh->print("alias $key='$tmp'\n");
	}
    } else {
	my $command= shift @$words;
	if ($command eq 'alias' or $command eq 'unalias') {
	    $psh->printerrln($psh->gt('alias: These commands may not be aliased.'));
	    return (0, undef);
	}
	if ($words->[0] and $words->[0] eq '=') {
	    shift @$words;
	}
	my $text= join(' ', @$words);
	if (!$text) {
	    my $tmp= $psh->{aliases}{$command};
	    if ($tmp) {
		$tmp=~ s/'/''/g;
		$psh->print("alias $command='$tmp'\n");
	    }
	} else {
	    $psh->{aliases}{$command}= $text;
	}
    }
    return (1,undef);
}


1;
