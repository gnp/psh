package Psh::Builtins::Function;
use strict;

use Psh::Util ':all';

=item * C<function>

Function is currently just a dummy built in for sh compatibility so
e.g. sourcing alias files containing functions won't cause
any trouble.

=cut

sub bi_function
{
	if ($Psh::interactive) {
		eval { use Psh::Builtins::Help; };
		Psh::Builtins::Help::bi_help('function');
	}
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
