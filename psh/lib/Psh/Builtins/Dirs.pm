package Psh::Builtins::Dirs;

require Psh::Support::Dirs;

=item * C<dirs> [n]

Prints out [the last n] entries in the cd history

=cut

sub bi_dirs {
	my $max=$#Psh::Support::Dirs::stack;
	if ($_[0] && $_[0]=~/^\d+$/) {
		$max=$_[0]-1 if $_[0]<=$max;
	}

	for (my $i=$max; $i>=0; $i--) {
		printf "%%%-2d ",$i;
		
		if ($i==$Psh::Support::Dirs::::stack_pos) {
			print " > ";
		} else {
			print "   ";
		}
		print $Psh::Support::Dirs::stack[$i]."\n";
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
