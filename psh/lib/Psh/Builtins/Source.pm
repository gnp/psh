package Psh::Builtins::Source;

=item * C<source FILE> [or C<. FILE>]

Read and process the contents of the given file as a sequence of B<psh>
commands.

=cut

sub bi_source
{
	local $Psh::echo = 0;
	local $Psh::interactive= 0;
	for my $file (split(' ',$_[0])) { Psh::process_file(Psh::Util::abs_path($file)); }

	return undef;
}

1;
