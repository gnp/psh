package Psh::Builtins::Delenv;

require Psh::Support::Env;
require Psh::Util;

=item * C<delenv NAME [NAME2 NAME3 ...]>

Deletes the names environment variables.

=cut

sub bi_delenv
{
	my @args= split(' ',$_[0]);
	if( !@args) {
		Psh::Util::print_error_i18n('usage_delenv');
		return (0,undef);
	}
	foreach my $var ( @args) {
		my @result = Psh::PerlEval::protected_eval("tied(\$$var)");
		my $oldtie = $result[0];
		if (defined($oldtie)) {
			Psh::PerlEval::protected_eval("untie(\$$var)");
		}
		my $oldval= $ENV{$var};
		delete($ENV{$var});
		return (1,$oldval);
	}
}

1;
