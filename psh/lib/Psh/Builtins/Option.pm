package Psh::Builtins::Option;

require Psh;
require Psh::Options;

=item * C<option[s]>

Lists the current configuration options

=item * C<option +NAME>

Activates an option

=item * C<option -NAME>

Deactivates an option

=item * C<option NAME=VALUE>

Sets an options

=cut


sub bi_option {
	my $line= shift;
	my @words= @{shift()};
	if (!@words) {
		my @opts= Psh::Options::list_options();
		@opts= sort @opts;
		foreach my $opt (@opts) {
			my $val='';
			my $tmpval= Psh::Options::get_option($opt);
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
					$val= qq['$tmpval'];
				} else {
					$val= 'undef';
				}
			}
			Psh::Util::print_out("$opt=$val\n");
		}
	} else {
		while (my $tmp= shift @words) {
			if (substr($tmp,0,1) eq '-') {
				Psh::Options::del_option(substr($tmp,1));
			} elsif (substr($tmp,0,1) eq '+') {
				Psh::Options::set_option(substr($tmp,1),1);
			} elsif ($tmp=~/=/) {
				my ($key,$val)= $tmp=~ /^(.*?)=(.*)$/;

				if (!$val or $val eq 'sub') {
					$val||='';
					$val.= shift @words;
					if ($val eq 'sub') {
						$val.= shift @words;
					}
				}
				my $char= substr($val,0,1);
				if ($char eq '(') {
					$val=qq:[$val]:;
				} elsif ($char ne "'" and $char ne '"' and $char ne '['
						and $char ne '{' and $char ne "\\" and
						 $val !~ /^sub\s*\{/) {
					$val=qq['$val'];
				}
				$val=~ s/[\033]/\\033/g;
				my @tmp= Psh::PerlEval::protected_eval($val,'eval');
				Psh::Options::set_option($key,$tmp[0]);
			} else {
				require Psh::Builtins::Help;
				Psh::Builtins::Help::bi_help('option');
				return (0,undef);
			}
		}
	}

	return (1,undef);
}


1;
