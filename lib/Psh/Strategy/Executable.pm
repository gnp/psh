package Psh::Strategy::Executable;

require Psh::Strategy;

use strict;
use vars qw(@ISA @noexpand $expand_arguments);

$expand_arguments=1;
@noexpand=('whois','/ezmlm-','/mail$','/mailx$','/pine$');
@ISA=('Psh::Strategy');

my %built_ins=();

sub consumes {
	return Psh::Strategy::CONSUME_TOKENS;
}

sub runs_before {
	return qw(eval);
}

sub applies {
	my $com= @{$_[2]}->[0];
	if ($com eq 'noglob' or $com eq 'noexpand') {
		$com= @{$_[2]}->[1];
	}
	my $executable= Psh::Util::which($com);
	return $executable if defined $executable;
	return '';
}

sub execute {
	my $inputline= ${$_[1]};
	my @words= @{$_[2]};
	my $tmp= shift @words;
	my $executable= $_[3];
	my $mod;
	if ($tmp eq 'noglob' or $tmp eq 'noexpand') {
		$mod=$tmp;
		$tmp= shift @words;
	}

	if (!$mod or $mod ne 'noexpand') {
		if ($expand_arguments) {
			my $flag=0;

			foreach my $re (@noexpand) {
				if ($tmp=~ m{$re}) {
					$flag=1;
					last;
				}
			}
			@words= Psh::PerlEval::variable_expansion(\@words) unless $flag;
		}
		if (!$mod or $mod ne 'noglob') {
			@words = Psh::Parser::glob_expansion(\@words);
		}
	}
	@words = map { Psh::Parser::unquote($_)} @words;

	return (join(' ',$executable,@words),[$executable,$tmp,@words], 0, undef, );
}

1;
