package Psh2::Builtins::Delenv;

=item * C<delenv NAME [NAME2 NAME3 ...]>

Deletes the named environment variables.

=cut

sub execute {
    my ($psh, $words)= @_;
    shift @$words;

    foreach my $var ( @$words ) {
#	my @result = Psh::PerlEval::protected_eval($psh,"tied(\$$var)");
#	my $oldtie = $result[0];
#	if (defined($oldtie)) {
#	    Psh::PerlEval::protected_eval($psh,"untie(\$$var)");
#	}
#	my $oldval= $ENV{$var};
	delete $ENV{$var};
    }
    return 1;
}

1;
