package Psh::Builtins::Which;

require Psh::Util;

=item * C<which command>

Locates the command in the filesystem.

=cut

sub bi_which
{
	my $command= shift @{$_[1]};
	if ($command) {
		$command= Psh::Util::which($command);
		if ($command) {
			Psh::Util::print_out("$command\n");
			return (1,undef);
		}
	}
	return (0,undef);
}

1;
