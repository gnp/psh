package Psh::Builtins::Pshtokenize;

use strict;

use Psh::Util ':all';

=item * C<pshtokenize> "command"

prints out the internal tokenization of the following command

=cut


sub bi_pshtokenize
{
	my $line= shift;
	eval "use Data::Dumper";
	if ($@) {
		print_error_i18n('bi_pshtoken_dumper');
		return undef;
	}
	my @tokens=Psh::Parser::make_tokens(Psh::Parser::unquote($line));
	print Dumper(\@tokens);
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
