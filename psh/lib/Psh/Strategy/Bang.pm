package Psh::Strategy::Bang;

require Psh::Strategy;


=item * C<bang>

If the input line starts with ! all remaining input will be
sent unchanged to /bin/sh

=cut



use vars qw(@ISA);
@ISA=('Psh::Strategy');

sub consumes {
	return Psh::Strategy::CONSUME_LINE;
}

sub runs_before {
	return qw(brace);
}

sub applies {
	return 'pass to sh' if substr(${$_[1]},0,1) eq '!';
}

sub execute {
	my $command= substr(${$_[1]},1);

	my $fgflag = 1;
	if ($command =~ /^(.*)\&\s*$/) {
		$command= $1;
		$fgflag=0;
	}

	Psh::OS::fork_process( $command, $fgflag, $command, 1);
	return undef;
}

1;
