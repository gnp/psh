package Psh::Builtins::History;
use strict;

use Psh::Util ':all';

=item * C<history> [n]

Prints out [the last n] entries in the history

=item * C<history> text [n]

Searches [the last n] entries in the command history and
prints them if they contain "text".

=cut


sub bi_history
{
	my $i;
	my $num = @Psh::history;
	my $grep= undef;

	return undef unless $num;

	if ($_[1]) {
		my @args=@{$_[1]};
		while (my $arg=shift @args) {
			if ($arg=~/^\d+$/) {
				$num=$arg if $arg<$num;
			}
			if ($arg=~/^\S+$/) {
				$grep=$arg;
			}
		}
	}

	for ($i=@Psh::history-$num; $i<@Psh::history; $i++) {
		next if $grep and $Psh::history[$i]!~/\Q$grep\E/;
		print_out(' '.sprintf('%3d',$i+1).'  '.$Psh::history[$i]."\n");
	}
	return undef;
}



1;

# Local Variables:
# mode:perl
# tab-width:4
# indent-tabs-mode:t
# c-basic-offset:4
# perl-label-offset:0
# perl-indent-level:4
# cperl-indent-level:4
# cperl-label-offset:0
# End:
