package Psh::Strategy::Eval;

require Psh::Strategy;

use strict;
use vars qw(@ISA);

@ISA=('Psh::Strategy');

sub new { Psh::Strategy::new(@_) }

sub consumes {
	return Psh::Strategy::CONSUME_TOKENS;
}

sub applies {
	return 'perl evaluation';
}

sub execute {
	my $todo= ${$_[1]};

	if( $_[4]) { # we are second or later in a pipe
		my $code;
		$todo=~ s/\} ?([qg])\s*$/\}/;
		my $mods= $1 || '';
		if( $mods eq 'q' ) { # non-print mode
			$code='while(<STDIN>) { @_= split /\s+/; '.$todo.' ; }';
		} elsif( $mods eq 'g') { # grep mode
			$code='while(<STDIN>) { @_= split /\s+/; print $_ if eval { '.$todo.' }; } ';
		} else {
			$code='while(<STDIN>) { @_= split /\s+/; '.$todo.' ; print $_ if $_; }';
		}
		return (sub {return Psh::PerlEval::protected_eval($code,'eval'); }, [], 0, undef);
    } else {
		return (sub {
			return Psh::PerlEval::protected_eval($todo,'eval');
		}, [], 0, undef);
	}
}

1;
