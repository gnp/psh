package Psh::Builtins::Strategy;

require File::Spec;
require Psh::Strategy;

=item * C<strategy list> shows the list of currently used strategies

=item * C<strategy available> shows the list of available strategies

=item * C<strategy add "name"> adds a strategy before the consume-all eval strategy

=item * C<strategy add "name" before "name"> inserts a strategy before the other one

=item * C<strategy add "name" after "name"> inserts a strategy after the other one

=item * C<strategy del "name"> removes a strategy

=item * C<strategy help "name"> shows help about a strategy

=cut

sub bi_strategy
{
	my ($line, $words)= @_;
	if( ! $words->[0]) {
		require Psh::Builtins::Help;
		Psh::Builtins::Help::bi_help('strategy');
		return undef;
	} elsif( $words->[0] eq 'add') {
		my $strat= lc($words->[1]);
		my $obj= Psh::Strategy::get($strat);
		my $pos;
		unless ($obj) {
			Psh::Util::print_error_i18n('bi_strategy_notfound',$strat);
			return 1;
		}

		if( @{$words}>3) {
			$pos= $words->[3];
			if( $pos !~ /^\d+$/) {
				$pos= Psh::Strategy::find($pos);
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
		Psh::Strategy::add($obj,$pos) if $obj;
	} elsif( $words->[0] eq 'del' ||
			 $words->[0] eq 'remove') {
		Psh::Strategy::remove($words->[1]);
	} elsif( $words->[0] eq 'show' ||
			 $words->[0] eq 'list') {
		Psh::Util::print_out_i18n('bi_strategy_list');
		my @list= Psh::Strategy::list();
		for( my $i=0; $i<@list; $i++) {
			Psh::Util::print_out(($i+1).") ".$list[$i]->name.
								 ($list[$i]->consumes == Psh::Strategy::CONSUME_LINE()?' (line)':'').
								 "\n");
		}
	} elsif( $words->[0] eq 'help') {
		require Psh::Builtins::Help;
		if( @{$words}<2) {
			Psh::Builtins::Help::bi_help('strategy');
		} else {
			my $tmp='';
			foreach my $line (@INC) {
				my $tmpfile= File::Spec->catfile(
								File::Spec->catdir($line,'Psh','Strategy'),
												 ucfirst($words->[1]).'.pm');
				$tmp= Psh::Builtins::Help::get_pod_from_file($tmpfile,
															$words->[1]);
				last if $tmp;
			}
			if( $tmp ) {
				Psh::OS::display_pod("=over 4\n".$tmp."\n=back\n");
			}
		}
	} elsif( $words->[0] eq 'available') {
		my @list= Psh::Strategy::available_list();
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
