package Psh2::Builtins::Use;

# Just a first version to ease debugging

sub execute {
    my ($psh, $words)= @_;
    eval "package main; use $words->[1];";
    if ($@) {
	print STDERR $@;
    }
}

1;

