package Psh::Builtins::History;
use strict;

use Psh::Util ':all';

=item * C<history> [n]

Prints out [the last n] entries in the history

=cut


sub bi_history
{
	my $i;
	my $num = @Psh::history;

	return undef unless $num;

	if ($_[0] && $_[0]=~/^\d+$/) {
		$num=$_[0] if $_[0]<$num;
	}

	for ($i=@Psh::history-$num; $i<@Psh::history; $i++) {
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
