package Psh::Builtins::Builtin;

require Psh::Strategy;
require Psh::Util;

=item * C<builtin COMMAND [ARGS]>

Run a shell builtin.

=cut

sub bi_builtin {
	my $text= shift;
	if (Psh::Strategy::active('built_in')) {
		return Psh::evl($text,'built_in','fallback_builtin');
	} else {
		print_error_i18n('bi_builtin_inactive');
		return (0,undef);
	}
}

sub cmpl_builtin {
	return cmpl_help(@_);
}

1;
