package Psh2::Builtins::Option;

=item * C<option[s]>

Lists the current configuration options

=item * C<option +NAME>

Activates an option

=item * C<option -NAME>

Deactivates an option

=item * C<option NAME=VALUE>

Sets an options

=item * C<option NAME>

Prints the value of an option

=cut

sub get_printable_option {
    my ($psh, $opt, $noquote)= @_;

    my $tmpval= $psh->get_option($opt);
    my $val= '';
    if (ref $tmpval) {
	if (ref $tmpval eq 'HASH') {
	    $val='{';
	    while (my ($k,$v)= each %$tmpval) {
		next unless defined $k;
		if (defined $v) {
		    $val.=" \'".$k."\' => \'".$v."\', ";
		} else {
		    $val.=" \'".$k."\' => undef, ";
		}
	    }
	    $val= substr($val,0,-2).' }';
	} elsif (ref $tmpval eq 'ARRAY') {
	    $val='[';
	    foreach (@$tmpval) {
		if (defined $_) {
		    $val.=" \'".$_."\', ";
		} else {
		    $val.=" undef, ";
		}
	    }
	    $val= substr($val,0,-2).' ]';
	} elsif (ref $tmpval eq 'CODE') {
	    $val='CODE';
	}
    } else {
	if (defined $tmpval) {
	    if ($noquote) {
		$val= $tmpval;
	    } else {
		$val= qq['$tmpval'];
	    }
	} else {
	    $val= 'undef';
	}
    }
    return $val;
}

sub execute {
    my ($psh, $words)= @_;
    shift @$words;
    if (!@$words) {
	my @opts= keys %{$psh->{option}};
	foreach (keys %env_option) {
	    push @opts, lc($_) if exists $ENV{uc($_)};
	}
	@opts= sort @opts;
	foreach my $opt (@opts) {
	    my $val= get_printable_option($psh, $opt);
	    $psh->print("$opt=$val\n");
	}
    } else {
	while (my $tmp= shift @$words) {
	    if (substr($tmp,0,1) eq '-') {
		$psh->del_option(substr($tmp,1));
	    } elsif (substr($tmp,0,1) eq '+') {
		$psh->set_option(substr($tmp,1),1);
	    } elsif (@$words>1 and $words->[0] eq '=') {
		shift @$words; shift @$words;
		$psh->set_option($tmp, $words->[1]);
	    } else {
		my $val= get_printable_option($psh,$tmp,1);
		$psh->print("$val\n");
	    }
	}
    }

    return 1;
}


1;
