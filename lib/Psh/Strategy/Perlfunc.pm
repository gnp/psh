package Psh::Strategy::Perlfunc;

=item * C<perlfunc>

Tries to detect perl builtins - this is helpful if you e.g. have
a print command on your system. This is a small, minimal version
without options which will react on your own sub's or on a limited
list of important perl builtins. Please also see the strategy
perlfunc_heavy

=cut

require Psh::Strategy;
require Psh::Strategy::Eval;

use vars qw(@ISA);
@ISA=('Psh::Strategy');


sub new { Psh::Strategy::new(@_) }

sub consumes {
	return Psh::Strategy::CONSUME_TOKENS;
}

sub runs_before {
	return qw(perlscript auto_resume executable);
}

my %perl_builtins = qw(
 print 1 printf 1 push 1 pop 1 shift 1 unshift 1 system 1
 package 1
 chop 1 chomp 1 use 1 for 1 foreach 1 sub 1 do 1
);

sub applies {
	my @words= @{$_[2]};
	my $line= ${$_[1]};

	my $fnname = $words[0];
	my $parenthesized = 0;

	# catch "join(':',@foo)" here as well:
	if ($fnname =~ m/\(/) {
		$parenthesized = 1;
		$fnname = (split('\(', $fnname))[0];
	}

	my $qPerlFunc = 0;
	if (exists $perl_builtins{$fnname}) {
		my $needArgs = $perl_builtins{$fnname};
		if ($needArgs > 0
			and ($parenthesized
				 or scalar(@{$_[2]}) >= $needArgs)) {
			$qPerlFunc = 1;
		}
	} elsif( $fnname =~ /^([a-zA-Z0-9_]+)\:\:([a-zA-Z0-9_:]+)$/) {
		if( $1 eq 'CORE') {
			my $needArgs = $perl_builtins{$2};
			if ($needArgs > 0
				and ($parenthesized or scalar(@{$_[2]}) >= $needArgs)) {
				$qPerlFunc = 1;
			}
		} else {
			$qPerlFunc = (Psh::PerlEval::protected_eval("defined(&{'$fnname'})"))[0];
		}
	} elsif( $fnname =~ /^[a-zA-Z0-9_]+$/) {
		$qPerlFunc = (Psh::PerlEval::protected_eval("defined(&{'$fnname'})"))[0];
	}

	return $line if $qPerlFunc;
	return '';
}

sub execute {
	my @args= @_;
	$args[4]=undef;
	return Psh::Strategy::Eval::execute(@args);
}

1;
