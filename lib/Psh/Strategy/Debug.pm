package Psh::Strategy::Debug;

=item * C<debug>

Entering "? commandline" will show information about the
way Perl Shell processes the input

=cut

$Psh::strategy_which{debug}= sub {
	my $fnname= ${$_[0]};

	if ($fnname=~/^\?/) {
		return "(debug $fnname)";
	}
    return '';
};

$Psh::strategy_eval{debug}=sub {
	my $fnname= ${$_[0]};
	eval "use Data::Dumper";
	if ($@) {
		print STDERR "Please install the module Data::Dumper first!\n";
	} else {
		print STDERR "Generated tokens:\n";
		my @tmp= Psh::Parser::make_tokens(substr($fnname,1));
		print STDERR Dumper(\@tmp);
	}
    return undef;
};

@always_insert_before= qw( executable);

1;
