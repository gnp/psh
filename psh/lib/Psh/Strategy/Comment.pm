package Psh::Strategy::Comment;


=item * C<bang>

If the input line starts with # all remaining input will be
ignored.

=cut


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
