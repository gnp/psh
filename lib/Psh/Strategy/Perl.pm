package Psh::Strategy::Perl;

=item * C<perl>

If the input line starts with p! all remaining input will be
sent unchanged to the perl interpreter

=cut


require Psh::Strategy;

@Psh::Strategy::Perl::ISA=('Psh::Strategy');

sub consumes {
	return Psh::Strategy::CONSUME_LINE;
}

sub runs_before {
	return qw(built_in brace);
}

sub applies {
	return 'perl evaluation' if substr(${$_[1]},0,2) eq 'p!';
}

sub execute {
	${$_[1]}= substr(${$_[1]},2);
	Psh::Strategy::Eval::execute(@_);
}

1;
