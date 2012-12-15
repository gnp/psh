package Psh::Builtins::Symbols;

require Psh::Util;

=item * C<symbols [package]>

Print out the symbols of each type used by a package. Note: in testing,
it bears out that the filehandles are present as scalars, and that arrays
are also present as scalars. The former is not particularly surprising,
since they are implemented as tied objects. But, use vars qw(@X) causes
both @X and $X to show up in this display. This remains mysterious.

=cut

sub bi_symbols
{
	my $pack = shift;
	my (@ref, @scalar, @array, @hash, @code, @glob, @handle);
	my @sym;

	$pack ||= $Psh::PerlEval::current_package;

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
			push @handle, "$sym"   if ref *{"${pack}::$sym"}{IO};
		}
	}

	Psh::Util::print_out("Package: ".$pack."\n");
	Psh::Util::print_out("Reference: ", join(' ', @ref),    "\n");
	Psh::Util::print_out("Scalar:    ", join(' ', @scalar), "\n");
	Psh::Util::print_out("Array:     ", join(' ', @array),  "\n");
	Psh::Util::print_out("Hash:      ", join(' ', @hash),   "\n");
	Psh::Util::print_out("Code:      ", join(' ', @code),   "\n");
	Psh::Util::print_out("Handle:    ", join(' ', @handle), "\n");
	return (1,undef);
}

1;
