package Psh2::Builtins::Package;

require Psh2::Language::Perl;

=item * C<package packagename>

Switches to another perl package.

=cut

sub execute {
    my ($psh, $words)=@_;
    shift @$words;
    my $pkg= $words->[0];
    if ($pkg) {
	$Psh2::Language::Perl::current_package= $pkg;
	return 1;
    } else {
	return 0;
    }
}

1;
