package Psh2::Builtins::If;

=item * C<if command { COMMANDS } [elsif ...] [ else { COMMANDS }]>

Control structure. If the first command returns true, execute the
specified commands. Otherwise try all elsif's and ultimately run
the else block, if no if before matched.

=cut

sub execute {
    my ($psh, $words)= @_;
    shift @$words;
    TRY: while (1) {
	my $cond= shift @$words;
	if (!defined $cond) {
	    $psh->printerrln($psh->gt('if: missing condition'));
	    return 0;
	}
	if (Psh2::Parser::is_group($cond)) {
	    $cond= Psh2::Parser::ungroup($cond);
	}
	$psh->process_variable($cond);
	my $action= shift @$words;
	if (!defined $action) {
	    $psh->printerrln($psh->gt('if: missing action'));
	    return 0;
	}
	if ($psh->{status}) {
	    $psh->process_variable($action);
	    last;
	} else {
	    my $next= shift @$words;
	    if ($next) {
		if ($next eq 'else') {
		    $action= shift @$words;
		    if (!defined $action) {
			$psh->printerrln($psh->gt('else: missing action'));
			return 0;
		    }
		    $psh->process_variable($action);
		    last;
		}
		elsif ($next eq 'elsif') {
		    next TRY;
		}
	    }
	    return 0;
	}
    }
    return $psh->{status};
}

1;
