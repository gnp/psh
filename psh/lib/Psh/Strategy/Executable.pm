package Psh::Strategy::Executable;


=item * C<executable>

This strategy will search for an executable file and execute it
if possible.

=cut

require Psh::Strategy;
require Psh::Options;

@Psh::Strategy::Executable::ISA=('Psh::Strategy');

my %built_ins=();

sub consumes {
	return Psh::Strategy::CONSUME_TOKENS;
}

sub runs_before {
	return qw(eval);
}

sub applies {
	my $com= @{$_[2]}->[0];
	my $executable= Psh::Util::which($com);
	return $executable if defined $executable;
	return '';
}

sub execute {
	my $inputline= ${$_[1]};
	my @words= @{$_[2]};
	my $tmp= shift @words;
	my $executable= $_[3];

	if (Psh::Options::get_option('expansion') and
	    (!$Psh::current_options or !$Psh::current_options->{noexpand})) {
		@words= Psh::PerlEval::variable_expansion(\@words);
	}
	if (Psh::Options::get_option('globbing') and
		(!$Psh::current_options or !$Psh::current_options->{noglob})) {
		@words = Psh::Parser::glob_expansion(\@words);
	}
	@words = map { Psh::Parser::unquote($_)} @words;

	return (1,join(' ',$executable,@words),[$executable,$tmp,@words], 0, undef, );
}

1;
