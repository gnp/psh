package Psh::Builtins::Elsif;

require Psh::Parser;
require Psh::Builtins::If;
require Psh;
require Psh::Util;

sub bi_elsif {
	return ($Psh::Builtins::If::last_success,undef) if $Psh::Builtins::If::last_success;
	return Psh::Builtins::If::bi_if(@_);
}
