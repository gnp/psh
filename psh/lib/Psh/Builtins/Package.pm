package Psh::Builtins::Package;

require Psh::Util;

=item * C<package packagename>

Switches to another perl package.

=cut

sub bi_package
{
	my $line= shift;
	my @words= @{shift()};

	$Psh::PerlEval::current_package= $words[0];
	return (1,undef);
}

1;
