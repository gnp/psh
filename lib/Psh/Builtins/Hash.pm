package Psh::Builtins::Hash;

require Psh::Util;

=item * C<hash>

Shows information about Psh's executable and path hashes.

=item * C<hash -r>

Empties the path and executable hashes. This might be necessary if
executables are renamed/removed/added while you're logged in.

=cut


sub bi_hash {
	my @words=@{$_[1]};

	if (@words) {
		while (my $sub= shift @words) {
			if (substr($sub,0,1) eq '-') {
				if ($sub eq '-r') {
					%Psh::Util::command_hash=();
					%Psh::Util::path_hash=();
				} else {
					Psh::Util::print_out("Unknown option $sub.\n");
				}
			} else {
			}
		}
	}
	else {
		while (my ($key,$val)= each %Psh::Util::command_hash) {
			Psh::Util::print_out("$key=$val\n");
		}
		while (my ($key,$val)= each %Psh::Util::path_hash) {
			Psh::Util::print_out("$key=$val\n");
		}
	}
}

1;
