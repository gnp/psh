package Psh::Strategy::Auto_cd;

=item * C<auto_cd>

If the input line matches the name of a directory then
it will be handled as an implicit cd.

=cut

require Psh::Strategy;
require Psh::Builtins::Cd;

use vars qw(@ISA);
@ISA=('Psh::Strategy');


sub new { Psh::Strategy::new(@_) }


sub consumes {
	return Psh::Strategy::CONSUME_TOKENS;
}

sub applies {
	my $dir= ${$_[2]}[0];
	return "auto-cd $dir" if -d $dir;
    return '';
}

sub execute {
	my $dir= ${$_[2]}[0];
	Psh::Builtins::Cd::bi_cd($dir);
	return undef;
}

sub runs_before {
	return qw(perlscript executable);
}

# Turn on directory completion for first words in line
$Psh::Completion::complete_first_word_dirs=1;

1;
