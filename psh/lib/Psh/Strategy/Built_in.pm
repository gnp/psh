package Psh::Strategy::Built_in;

require Psh::Strategy;
require Psh::Support::Builtins;

use strict;
use vars qw(@ISA);

@ISA=('Psh::Strategy');

Psh::Support::Builtins::build_autoload_list();

sub new { Psh::Strategy::new(@_) }

sub consumes {
	return Psh::Strategy::CONSUME_TOKENS;
}

sub runs_before {
	return qw(executable auto_resume auto_cd);
}

sub applies {
	my $fnname= ${$_[2]}[0];

	if( Psh::Support::Builtins::is_builtin($fnname)) {
		eval 'use Psh::Builtins::'.ucfirst($fnname);
		if ($@) {
			Psh::Util::print_error_i18n('builtin_failed',$@);
		}
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
	$coderef= *{join('','Psh::Builtins::',ucfirst($command),
					 '::bi_',$command)};
	return (sub { &{$coderef}($rest,\@words); }, [], 0, undef );
}

1;
