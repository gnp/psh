package Psh::Builtins::If;

require Psh::Parser;
require Psh;
require Psh::Util;

sub bi_if {
	my @words=@{$_[1]};
	my $success=0;
	my @result=(0,undef);
	my @cond;

	TRY: while (@words>0) {
		@cond=();
		while (@words>0) {
			last if substr($words[0],0,1) eq '{';
			push @cond, shift @words;
		}
		unless (@words) {
			Psh::Util::print_error("Missing action for if\n");
			return (0,undef);
		}
		my $cond= join(' ',@cond);
		($success)= Psh::evl(Psh::Parser::ungroup($cond));
		$Psh::Builtins::If::last_success= $success;

		if ($success) {
			return Psh::evl(Psh::Parser::ungroup(shift @words));
		} else {
			shift @words; # ignore the if-block
			my $next= shift @words;
			next TRY if $next eq 'elsif';
			if ($next eq 'else') {
				return Psh::evl(Psh::Parser::ungroup(shift @words));
			}
			return (0,undef);
		}
	}
	return (1,undef);
}

1;
