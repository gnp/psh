package Psh2::Language::C;

sub execute {
    my ($psh, $words)= @_;
    shift @$words;
    my $tmp= Psh2::Parser::ungroup(join(' ',@$words));

    my $text= qq[package tmp;
use Inline C => <<'ENDOFOURCCODE';
void _tmpfunc() { $tmp ; }
ENDOFOURCCODE
_tmpfunc();
];
    eval $text;
    if ($@) {
	print STDERR $@;
    }
}

sub internal {
    return 1;
}

1;
