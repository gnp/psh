package Psh::Builtins::Builtin;

=item * C<builtin COMMAND [ARGS]>

Run a shell builtin.

=cut

sub bi_builtin {
	my $text= shift;
	Psh::evl($text,'built_in','fallback_builtin');
	return 1;
}

sub cmpl_builtin {
	return cmpl_help(@_);
}

1;
