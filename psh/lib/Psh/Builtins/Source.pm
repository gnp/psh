package Psh::Builtins::Source;

require Psh::Util;
require Psh;

=item * C<source FILE> [or C<. FILE>]

Read and process the contents of the given file as a sequence of B<psh>
commands.

=cut

sub bi_source
{
	local $Psh::echo = 0;
	local $Psh::interactive= 0;
	foreach my $file (@{$_[1]}) {
		print "$file\n";
		Psh::process_file(Psh::Util::abs_path($file));
	}

	return (1,undef);
}

1;
