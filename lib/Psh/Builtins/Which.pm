package Psh::Builtins::Which;

use Psh::Util ':all';

=item * C<which COMMAND-LINE>

Describe how B<psh> will execute the given COMMAND-LINE, under the
current setting of C<$Psh::strategies>.

=cut

sub bi_which
{
	my $line   = shift;

	if (!defined($line) or $line eq '') {
		print_error_i18n('bi_which_no_command');
		return 1;
	}


	print_debug("[which $line]\n");

	my @words= Psh::Parser::std_tokenize($line);
	foreach my $strat (@Psh::unparsed_strategies) {
		if (!exists($Psh::strategy_which{$strat})) {
			print_warning_i18n('no_such_strategy',$strat,'which');
			next;
		}

		my $how = &{$Psh::strategy_which{$strat}}(\$line,\@words);

		if ($how) {
			if (ref $how eq 'ARRAY') {
				$how=$how->[0]
			}
			print_out_i18n('evaluates_under',$line,$strat,$how);
			return 0;
		}
	}


	my @words= Psh::Parser::decompose(
							'(\s+|\||;|\&\d*|[0-9&]*>|[0-9&]*<|\\|=)',
							$line, undef, 1,
							{"'"=>"'","\""=>"\"","{"=>"}"});
	# TODO: The special rules are missing so this is not really correct

	my $line= join ' ', @words;
	foreach my $strat (@Psh::strategies) {
		if (!defined($Psh::strategy_which{$strat})) {
			print_warning_i18n('no_such_strategy',$strat,'which');
			next;
		}

		my $how = &{$Psh::strategy_which{$strat}}(\$line,\@words);

		if ($how) {
			print_out_i18n('evaluates_under',$line,$strat,$how);
			return 0;
		}
	}

	print_warning_i18n('clueless',$line,'which');
	return 1;
}

1;
