package Psh::Builtins::Rehash;

require Psh::Util;

=item * C<rehash>

Empties the path and executable hashes. This might be necessary if
executables are renamed/removed/added while you're logged in.

=cut

sub bi_rehash
{
	%Psh::Util::command_hash=();
	%Psh::Util::path_hash=();
	return (1,undef);
}

1;
