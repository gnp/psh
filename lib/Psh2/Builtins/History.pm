package Psh2::Builtins::History;

=item * C<history> [n]

Prints out [the last n] entries in the history

=item * C<history text [n]>

Searches [the last n] entries in the command history and
prints them if they contain "text".

=cut

sub execute {
	my ($psh, $words)= @_;
	shift @$words;

	my $i;
	my $num= scalar(@{$psh->{history}});
	my $grep= undef;

	return 0 unless $num;

	if (@$words) {
		while (my $arg=shift @$words) {
			if ($arg=~/^\d+$/) {
				$num=$arg if $arg<$num;
			}
			if ($arg=~/^\S+$/) {
				$grep=$arg;
			}
		}
	}

	my $success=0;
	my $max= scalar(@{$psh->{history}});

	if ($grep) {
		$max--;
	}
	for ($i=@{$psh->{history}}-$num; $i<$max; $i++) {
		next if $grep and $psh->{history}[$i]!~/\Q$grep\E/;
		$psh->println(' '.sprintf('%3d',$i+1).'  '.$psh->{history}[$i]);
		$success=1;
	}
	return $success;
}

1;
