package Psh::Strategy::Brace;

require Psh::Strategy;
require Psh::Strategy::Eval;

use strict;
use vars(@ISA);

@ISA=('Psh::Strategy');

sub consumes {
	return Psh::Strategy::CONSUME_TOKENS;
}

sub runs_before {
	return qw(buil_tin);
}

sub applies {
	return 'perl evaluation' if substr($$_[1],0,1) eq '{';
}

sub execute {
	Psh::Strategy::Eval::execute(@_);
}

1;
