package Psh2::Language::Osascript;

sub execute {
    my ($psh, $words)= @_;
    shift @$words;

    if ($^O ne 'darwin') {
        die "Only possible on Mac OS X!";
    }

    my $tmp= join(' ',@$words);
    $tmp=~ s/^\s+//g; $tmp=~ s/\s+$//g;
    $tmp= Psh2::Parser::ungroup($tmp);
    open(OSASCRIPT, "| osascript");
    print OSASCRIPT $tmp;
    close(OSASCRIPT);
}

sub internal {
    return 0;
}

1;
