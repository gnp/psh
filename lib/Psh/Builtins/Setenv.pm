package Psh::Builtins::Setenv;

require Psh::Support::Env;
require Psh::Util;

=item * C<setenv NAME [=] VALUE>

Sets the environment variable NAME to VALUE.

=cut

sub bi_setenv
{
	my $var = Psh::Support::Env::do_setenv(@_);
	if (!$var) {
		Psh::Util::print_error_i18n('usage_setenv');
		return (0,undef);
	}
	return (1,undef);
}


1;
