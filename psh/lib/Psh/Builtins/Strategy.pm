package Psh::Builtins::Strategy;

use File::Spec;

=item * C<strategy list> shows the list of currently used strategies

=item * C<strategy available> shows the list of available strategies

=item * C<strategy add "name"> adds a strategy before the consume-all eval strategy

=item * C<strategy add "name" before "name"> inserts a strategy before the other one

=item * C<strategy add "name" after "name"> inserts a strategy after the other one

=item * C<strategy del "name"> removes a strategy

=item * C<strategy help "name"> shows help about a strategy

=cut

sub _find_in_strategies {
	my $strat= shift;
	for( my $i=0; $i<@Psh::strategies; $i++) {
		if( $Psh::strategies[$i] eq $strat) {
			$pos=$i;
			return $pos;
		}
	}
	return -1;
}

sub _generate_strategy_list {
	my @result= ();
	foreach my $tmp (@INC) {
		my $tmpdir= File::Spec->catdir($tmp,'Psh','Strategy');
		push @result, map { s/.pm$//; lc($_) } Psh::OS::glob('*.pm',$tmpdir);
	}
	return @result;
}

sub bi_strategy
{
	my ($line, $words)= @_;

	if( ! $words->[0]) {
		require Psh::Builtins::Help;
		Psh::Builtins::Help::bi_help('strategy');
		return undef;
	} elsif( $words->[0] eq 'add') {
		my $strat= $words->[1];
		my $pos= $#Psh::strategies; # Add right before eval
		if( !exists($Psh::strategy_which{$strat})) {
			my $tmp='Psh::Strategy::'.ucfirst($strat);
			eval "use $tmp";
			if( !exists($Psh::strategy_which{$strat})) {
				Psh::Util::print_error_i18n('bi_strategy_notfound',$strat);
				return 1;
			}
			my @insert_before= eval '@'.$tmp.'::always_insert_before';
			if( @insert_before) {
				foreach( @insert_before) {
					my $tmp= _find_in_strategies($_);
					$pos=$tmp if( $tmp<$pos && $tmp>0);
				}
			}
		}
		if( @{$words}>3) {
			$pos= $words->[3];
			if( $pos !~ /^\d+$/) {
				$pos=_find_in_strategies($pos);
				if( $pos<0) {
					Psh::Util::print_error_i18n('bi_strategy_notfound',$words->[3]);
					return 1;
				}
			} else {
				$pos--;
			}
			if( $words->[2] eq 'after') {
				$pos++;
			}
		}
		splice(@Psh::strategies,$pos,0,$strat);
	} elsif( $words->[0] eq 'del' ||
			 $words->[0] eq 'remove') {
		for( my $i=0; $i<@Psh::strategies; $i++) {
			if( $words->[1] eq $Psh::strategies[$i]) {
				splice @Psh::strategies,$i,1;
				last;
			}
		}
	} elsif( $words->[0] eq 'show' ||
			 $words->[0] eq 'list') {
		Psh::Util::print_out_i18n('bi_strategy_list');
		for( my $i=0; $i<@Psh::strategies; $i++) {
			Psh::Util::print_out(($i+1).") ".$Psh::strategies[$i]."\n");
		}
	} elsif( $words->[0] eq 'help') {
		require Psh::Builtins::Help;
		if( @{$words}<2) {
			Psh::Builtins::Help::bi_help('strategy');
			return undef;
		}
		my $tmp='';
		foreach my $line (@INC) {
			my $tmpfile= File::Spec->catfile(
								  File::Spec->catdir($line,'Psh','Strategy'),
										  ucfirst($words->[1]).'.pm');
			$tmp= Psh::Builtins::Help::get_pod_from_file($tmpfile,$arg);
			last if $tmp;
		}
		if( $tmp ) {
			Psh::OS::display_pod("=over 4\n".$tmp."\n=back\n");
		}
	} elsif( $words->[0] eq 'available') {
		my @list= _generate_strategy_list();
		foreach( @list) {
			Psh::Util::print_out($_."\n");
		}
	} else {
		Psh::Util::print_error_i18n('bi_strategy_wrong_arg');
	}
	return undef;
}

sub cmpl_strategy {
	my( $text, $dummy, $starttext) = @_;
	my @words= split ' ',$starttext;

	$Psh::Completion::ac=' ';

	if( @words >= 4) {
		return (1,grep { Psh::Util::starts_with($_,$text) }
				@Psh::strategies);
	} elsif( @words >= 3) {
		return (1,grep { Psh::Util::starts_with($_,$text) }
				qw(before after));
	} elsif( @words >= 2) {
		if( $words[1] eq 'del' || $words[1] eq 'remove') {
			return (1,grep { Psh::Util::starts_with($_,$text) }
					@Psh::strategies);
		} elsif( $words[1] eq 'help' || $words[1] eq 'add') {
			return (1, grep { Psh::Util::starts_with($_,$text) }
					_generate_strategy_list());
		}
	} else {
		return (1,grep { Psh::Util::starts_with($_,$text) }
				qw(show list del help remove add available));
	}
}


1;
