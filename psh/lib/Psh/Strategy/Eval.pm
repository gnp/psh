package Psh::Strategy::Eval;

=item * C<eval>

All input will be evaluated by the perl interpreter without
any conditions.

=cut

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
		return (1,sub {return 1,Psh::PerlEval::protected_eval($code,'eval'); }, [], 0, undef);
    } else {
		return (1,sub {
					local @Psh::tmp= Psh::PerlEval::protected_eval($todo,'eval');
					return ((@Psh::tmp && $Psh::tmp[0])?1:0, @Psh::tmp);
		}, [], 0, undef);
	}
}

1;
