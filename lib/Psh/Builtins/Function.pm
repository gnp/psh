package Psh::Builtins::Function;
use strict;

use Psh::Util ':all';

=item * C<function>

Function tries to emulate the functionality of bash's function builtin
=cut

sub bi_function
{
	$_[0]=~/(\S+)\s*\{(.*)\}/;
	my $name=$1;
	my $def= $2;
	Psh::PerlEval::protected_eval(qq[sub $name {Psh::evl('$def')}],'eval');
	return undef;
}

1;

# Local Variables:
# mode:perl
# tab-width:4
# indent-tabs-mode:t
# c-basic-offset:4
# perl-label-offset:0
# perl-indent-level:4
# cperl-indent-level:4
# cperl-label-offset:0
# End:
