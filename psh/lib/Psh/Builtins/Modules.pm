package Psh::Builtins::Modules;

require Psh::Util;

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

	Psh::Util::print_out('Pragmas:    '.join(', ',@pragmas)."\n\n");
	Psh::Util::print_out('Modules:    '.join(', ',@modules)."\n\n");
	Psh::Util::print_out('Builtins:   '.join(', ',@builtins)."\n\n");
	Psh::Util::print_out('Strategies: '.join(', ',@strategies)."\n\n");
	Psh::Util::print_out('Psh:        '.join(', ',@psh)."\n\n");
	return (0,undef);
}

1;
