package Psh2::Builtins::Symbols;

=item * C<symbols [package]>

Print out the symbols of each type used by a package. Note: in testing,
it bears out that the filehandles are present as scalars, and that arrays
are also present as scalars. The former is not particularly surprising,
since they are implemented as tied objects. But, use vars qw(@X) causes
both @X and $X to show up in this display. This remains mysterious.

=cut

sub execute {
    my ($psh, $words)= @_;
    shift @$words;
    my $pack= shift @$words;
    my (@ref, @scalar, @array, @hash, @code, @glob, @handle);
    my @sym;

    $pack ||= $psh->{current_package};

    {
	no strict qw(refs);
	@sym = keys %{*{"${pack}::"}};
    }

    for my $sym (sort @sym) {
	next unless $sym =~ m/^[a-zA-Z]/; # Skip some special variables
	next if     $sym =~ m/::$/;       # Skip all package hashes

	{
	    no strict qw(refs);

	    push @ref,    "\$$sym" if ref *{"${pack}::$sym"}{SCALAR} eq 'REF';
	    push @scalar, "\$$sym" if ref *{"${pack}::$sym"}{SCALAR} eq 'SCALAR';
	    push @array,  "\@$sym" if ref *{"${pack}::$sym"}{ARRAY}  eq 'ARRAY';
	    push @hash,   "\%$sym" if ref *{"${pack}::$sym"}{HASH}   eq 'HASH';
	    push @code,   "\&$sym" if ref *{"${pack}::$sym"}{CODE}   eq 'CODE';
	}
    }

    $psh->println("Package: ".$pack);
    $psh->println("Reference: ", join(' ', @ref));
    $psh->println("Scalar:    ", join(' ', @scalar));
    $psh->println("Array:     ", join(' ', @array));
    $psh->println("Hash:      ", join(' ', @hash));
    $psh->println("Code:      ", join(' ', @code));
    return 1;
}

1;
