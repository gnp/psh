package Psh::Builtins::Fallback::Env;

=item * C<env>

Prints out the current environment

=cut

sub bi_env
{
	foreach my $key (keys %ENV) {
		print_out("$key=$ENV{$key}\n");
	}
	return undef;
}

1;
