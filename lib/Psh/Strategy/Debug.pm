package Psh::Strategy::Debug;

=item * C<debug>

Entering "? commandline" will show information about the
way Perl Shell processes the input

=cut

require Psh::Strategy;
require Psh::Support::Debug;

use vars qw(@ISA);
@ISA=('Psh::Strategy');

sub new { Psh::Strategy::new(@_) }

sub consumes {
	return Psh::Strategy::CONSUME_LINE;
}

sub runs_before {
	return qw(executable auto_cd built_in);
}

sub applies {
	my $fnname= ${$_[1]};

	if ($fnname=~/^\?/) {
		return "debug $fnname";
	}
    return '';
}

sub execute {
	my $fnname= ${$_[1]};
	my @tmp= Psh::Parser::make_tokens(substr($fnname,1));
	print "Tokenization:\n";
	print Psh::Support::Debug::explain_tokens(\@tmp)."\n";
	@tmp= Psh::Parser::parse_line(substr($fnname,1));
	use Data::Dumper;
	print Dumper(\@tmp);
    return (1,undef);
}

1;
