package Psh::Builtins::Modules;

use Psh::Util ':all';

=item * C<modules>

Displays a list of loaded Perl Modules

=cut

sub bi_modules
{
	my @modules= sort keys %INC;
	my (@pragmas,@psh);
	@modules= map { s/\.pm$//; s/\//::/g; $_ }
	  grep { /\.pm$/ } @modules;
	@pragmas= grep { /^[a-z]/ } @modules;
    @psh= grep { /^Psh/ } @modules;
	@modules= grep { $_ !~ /^Psh/ } grep { /^[A-Z]/ } @modules;
	print_out('Pragmas:  '.join(', ',@pragmas)."\n");
	print_out('Modules:  '.join(', ',@modules)."\n");
	print_out('psh mods: '.join(', ',@psh)."\n");
	return undef;
}

1;
