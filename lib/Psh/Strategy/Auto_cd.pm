package Psh::Strategy::Auto_cd;

=item * C<auto_cd>

If the input line matches the name of a directory then
it will be handled as an implicit cd.

=cut

$Psh::strategy_which{auto_cd}= sub {
	my $fnname= ${$_[1]}[0];

    if( -d $fnname) {
	    return "(auto-cd $fnname)";
	}
    return '';
};

$Psh::strategy_eval{auto_cd}=sub {
	my $fnname= ${$_[1]}[0];
    Psh::Builtins::bi_cd($fnname);
    return undef;
};

# Turn on directory completion for first words in line
$Psh::Completion::complete_first_word_dirs=1;

@always_insert_before= qw( perlscript executable);

1;
