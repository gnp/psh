package Psh2::Builtins::Sub;

require Psh2::Language::Perl;

sub execute {
    my ($psh, $words)= @_;
    shift @$words;

    $psh->delete_function($words->[0]);
    Psh2::Language::Perl::protected_eval
      ($psh, "sub $words->[0] $words->[1]\n");
    my $coderef= *{$Psh2::Language::Perl::current_package.'::'.$words->[0]};
    if (defined $coderef) {
	my $wrapper= sub {
	    my ($psh, $words)= @_;
	    shift @$words;
	    &$coderef(@$words);
	};
	$psh->add_function($words->[0], $wrapper, undef);
	return 1;
    }
    return 0;
}

1;
