package Psh::Strategy::Built_in;

require Psh::Strategy;

use strict;
use vars qw(@ISA);

@ISA=('Psh::Strategy');

my %built_ins=();

sub new { Psh::Strategy::new(@_) }

sub consumes {
	return Psh::Strategy::CONSUME_TOKENS;
}

sub runs_before {
	return qw(executable auto_resume auto_cd);
}

sub applies {
	my $fnname= ${$_[2]}[0];

	if( $built_ins{$fnname}) {
		eval 'use Psh::Builtins::'.ucfirst($fnname);
		if ($@) {
			Psh::Util::print_error_i18n('builtin_failed',$@);
		}
		return "builtin $fnname";
	}
	no strict 'refs';
	if( ref *{"Psh::Builtins::bi_$fnname"}{CODE} eq 'CODE') {
		return "builtin $fnname";
	}
	return '';
}

sub execute {
	my $line= ${$_[1]};
	my @words= @{$_[2]};
	my $command= shift @words;
	my $rest= join(' ',@words);
	my $coderef;

	no strict 'refs';
	if ($built_ins{$command}) {
		$coderef= *{join('','Psh::Builtins::',ucfirst($command),
						 '::bi_',$command)};
	} else {
		$coderef= *{"Psh::Builtins::bi_$command"};
	}
	return (sub { &{$coderef}($rest,\@words); }, [], 0, undef );
}

1;
