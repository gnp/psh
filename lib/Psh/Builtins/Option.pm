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

=item * C<option NAME>

Prints the value of an option

=cut


sub bi_option {
	my $line= shift;
	my @words= @{shift()};
	if (!@words) {
		my @opts= Psh::Options::list_options();
		@opts= sort @opts;
		foreach my $opt (@opts) {
			my $val= Psh::Options::get_printable_option($opt);
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
				} elsif ($char ne "'" and $char ne '"' and 
						 $char ne '[' and $char ne '{' and $char ne "\\" and
						 $char ne '%' and $char ne '$' and $char ne '%' and
						 $val !~ /^sub\s*\{/) {
					$val=qq['$val'];
				}
				$val=~ s/\033/\\033/g;
				my @tmp= Psh::PerlEval::protected_eval($val,'eval');
				$val= $tmp[0];
				if (@tmp>1) {
					$val= \@tmp;
				}
				Psh::Options::set_option($key, $val);
			} else {
				my $val= Psh::Options::get_printable_option($tmp,1);
				Psh::Util::print_out("$val\n");
			}
		}
	}

	return (1,undef);
}


1;
