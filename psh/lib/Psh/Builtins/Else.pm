package Psh::Builtins::Else;

require Psh::Parser;
require Psh::Builtins::If;
require Psh;
require Psh::Util;

sub bi_else {
	my @words=@{$_[1]};
	return ($Psh::Builtins::If::last_success,undef) if $Psh::Builtins::If::last_success;
	return Psh::evl(Psh::Parser::ungroup(shift @words));
}
