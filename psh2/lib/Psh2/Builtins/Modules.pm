package Psh2::Builtins::Modules;

=item * C<modules>

Displays a list of loaded Perl Modules

=cut

sub execute {
    my @modules= sort keys %INC;
    my (@pragmas,@strategies,@builtins,@psh);
    @modules= map { s/\.pm$//; s/\//::/g; $_ }
      grep { /\.pm$/ } @modules;
    
    @pragmas= grep { /^[a-z]/ } @modules;
    @psh= grep { /^Psh2/ } @modules;
    @modules= grep { $_ !~ /^Psh2/ } grep { /^[A-Z]/ } @modules;
    
    @builtins= grep { /^Psh2::Builtins::/ } @psh;
    @psh=
      map { s/^Psh2:://; $_ }
	grep { $_ !~ /^Psh2::Builtins::/ } @psh;
    
    @builtins= map { s/^Psh2::Builtins:://; $_ }	@builtins;
    
    print 'Pragmas:    '.join(', ',@pragmas)."\n\n";
    print 'Modules:    '.join(', ',@modules)."\n\n";
    print 'Builtins:   '.join(', ',@builtins)."\n\n";
    print 'Psh:        '.join(', ',@psh)."\n\n";
}

1;
