package Psh2::Builtins::Package;

require Psh2::Language::Perl;

=item * C<package packagename>

Switches to another namespace. Psh namespaces are equivalent to
Perl namespaces.

=cut

sub execute {
    my ($psh, $words)=@_;
    shift @$words;
    my $pkg= $words->[0];
    if ($pkg) {
	$psh->{current_package}= $pkg;
	return 1;
    } else {
	return 0;
    }
}

1;
