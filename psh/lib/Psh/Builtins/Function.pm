package Psh::Builtins::Function;

require Psh::PerlEval;
require Psh::Support::Functions;

=item * C<function>

Function tries to emulate the functionality of bash's function builtin

=cut

sub bi_function
{
	$_[0]=~/^\s*(\S+)\s*\{(.*)\}\s*$/s;
	my $name=$1;
	my $def= $2;
	if ($name and $def) {
		Psh::Support::Functions::add_function($name,$def);
		Psh::PerlEval::protected_eval(qq[sub $name { Psh::Support::Functions::call_function($name); }], 'eval');
	}
	return undef;
}

1;
