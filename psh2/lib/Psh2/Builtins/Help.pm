package Psh2::Builtins::Help;

require POSIX;

sub get_pod_from_file {
    my $tmpfile= shift;
    my $arg= shift;
    my $tmp='';
    if( -r $tmpfile) {
	open(FILE, "< $tmpfile");
	my $add=0;
	while(<FILE>) {
	    if( !$add && /\=item \* C\<$arg[ >]/) {
		$tmp="\n".$_;
		$add=1;
	    } elsif( $add) {
		$tmp.=$_;
	    }
	    if( $add && $_ =~ /\=cut/) {
		$add=0;
		last;
	    }
	}
	close(FILE);
    }
    return $tmp;
}

sub display_pod {
    my ($psh,$text)= @_;
    my $parser;

    eval {
	require Pod::Text::Color;
	$parser= Pod::Text::Color->new( sentence => 0,
					indent => 2);
    };
    if ($@) {
	eval {
	    require Pod::Text;
	    $parser= Pod::Text->new( sentence => 0,
				     indent => 2);
	};
	if ($@) {
	    $psh->printerr($@);
	    $psh->print($text);
	}
    }
    my $tmp= POSIX::tmpnam();

    local *TMP;
    open( TMP,">$tmp");
    print TMP $text;
    close(TMP);

    $parser->parse_from_file($tmp, '-');
    unlink($tmp);
}

=item * C<help [COMMAND]>

If COMMAND is specified, print out help on it; otherwise print out a list of
B<psh> builtins.

=cut

sub execute {
    my ($psh, $words)= @_;
    shift @$words;
    my $arg= shift @$words;
    if( $arg) {
	my $tmp;
	my $filename= $psh->{builtin}{lc($arg)};
	if ($filename) {
	    $tmp= get_pod_from_file($filename,$arg);
	    if( $tmp ) {
		display_pod($psh, "=over 4\n".$tmp."\n=back\n");
	    } else {
		$psh->printferrln($psh->gt('help: no help for builtin %s available.'), $arg);
	    }
	} else {
	    $psh->printferrln($psh->gt('help: %s seems to be no builtin.'), $arg);
	}
    } else {
	$psh->println($psh->gt('psh2 supports following built-in commands:'));
	$psh->fe->print_list( sort { lc($a) cmp lc($b)} keys %{$psh->{builtin}});
    }
    return 1;
}

1;
