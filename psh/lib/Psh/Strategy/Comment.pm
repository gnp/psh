package Psh::Strategy::Comment;

require Psh::Strategy;

use strict;
use vars qw(@ISA);

@ISA=('Psh::Strategy');

sub consumes {
	return Psh::Strategy::CONSUME_LINE;
}

sub runs_before {
	return qw(bang brace);
}

sub applies {
	return 'comment' if substr(${$_[1]},0,1) eq '#';
}

sub execute {
	undef;
}

1;
