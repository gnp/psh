package Psh::Builtins::Modules;

use Psh::Util ':all';

=item * C<modules>

Displays a list of loaded Perl Modules

=cut

sub bi_modules
{
	my @modules= sort keys %INC;
	my (@pragmas,@strategies,@builtins,@psh);
	@modules= map { s/\.pm$//; s/\//::/g; $_ }
	  grep { /\.pm$/ } @modules;

	@pragmas= grep { /^[a-z]/ } @modules;
    @psh= grep { /^Psh/ } @modules;
	@modules= grep { $_ !~ /^Psh/ } grep { /^[A-Z]/ } @modules;

	@builtins= grep { /^Psh::Builtins::/ } @psh;
	@strategies= grep { /^Psh::Strategy::/ } @psh;
	@psh=
	  map { s/^Psh:://; $_ }
		grep { $_ !~ /^Psh::Builtins::/ && $_!~ /^Psh::Strategy::/ } @psh;

	@builtins= map { s/^Psh::Builtins:://; $_ }	@builtins;

	@strategies= map { s/^Psh::Strategy:://; $_ } @strategies;

	print_out('Pragmas:    '.join(', ',@pragmas)."\n\n");
	print_out('Modules:    '.join(', ',@modules)."\n\n");
	print_out('Builtins:   '.join(', ',@builtins)."\n\n");
	print_out('Strategies: '.join(', ',@strategies)."\n\n");
	print_out('Psh:        '.join(', ',@psh)."\n\n");
	return undef;
}

1;
