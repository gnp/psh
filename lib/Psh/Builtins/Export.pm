package Psh::Builtins::Export;

require Psh::Support::Env;
require Psh::Options;
require Psh::Util;

=item * C<export VAR [=VALUE]>

Just like setenv, below, except that it also ties the variable (in the
Perl sense) so that subsequent changes to the variable automatically
affect the environment. Variables who are lists and appear in option
'array_exports' will also by tied to the array of the same name.
Note that the variable must be specified without any Perl specifier
like C<$> or C<@>.

=cut

sub bi_export
{
	my $var = Psh::Support::Env::do_setenv(@_);
	if ($var) {
		my @result = Psh::PerlEval::protected_eval("tied(\$$var)");
		my $oldtie = $result[0];
		if (defined($oldtie)) {
			if (ref($oldtie) ne 'Env') {
				Psh::Util::print_warning_i18n('bi_export_tied',$var,$oldtie);
			}
		} else {
			Psh::PerlEval::protected_eval("use Env '$var';");
			my $ae= Psh::Options::get_option('array_exports');
			if( $ae and $ae->{$var}) {
				eval {
					require Env::Array;
				};
				if( ! $@) {
					Psh::PerlEval::protected_eval("use Env::Array qw($var $ae->{var});",'hide');
				}
			}
		}
	} else {
		Psh::Util::print_error_i18n('usage_export');
		return (0,undef);
	}
	return (1,undef);
}

1;

