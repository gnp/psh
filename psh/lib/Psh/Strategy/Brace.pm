package Psh::Strategy::Brace;


=item * C<bang>

Input within curly braces will be sent unchanged to the perl
interpreter.

=cut


require Psh::Strategy;
require Psh::Strategy::Eval;

use strict;
use vars qw(@ISA);

@ISA=('Psh::Strategy');

sub consumes {
	return Psh::Strategy::CONSUME_TOKENS;
}

sub runs_before {
	return qw(built_in);
}

sub applies {
	return 'perl evaluation' if substr(${$_[1]},0,1) eq '{';
}

sub execute {
	Psh::Strategy::Eval::execute(@_);
}

1;
