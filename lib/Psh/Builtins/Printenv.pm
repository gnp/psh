package Psh::Builtins::Printenv;

require Psh::Support::Env;
require Psh::Util;

=item * C<printenv NAME [NAME ...]>

Displays the named environment variables

=cut

sub bi_printenv
{
	my @names= @{$_[1]};
	if (@names) {
		foreach (@names) {
			Psh::Util::print_out($ENV{uc($_)}."\n");
		}
	} else {
		while (my ($key,$val)= each %ENV) {
			Psh::Util::print_out("$key=$val\n");
		}
	}
	return (1,undef);
}


sub cmpl_printenv {
	my( $text, $pre, $start, $line, $startchar) = @_;
	return 1,grep { Psh::Util::starts_with($_,$text)} keys %ENV;
}


1;
