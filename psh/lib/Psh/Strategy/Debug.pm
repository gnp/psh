package Psh::Strategy::Debug;

=item * C<debug>

Entering "? commandline" will show information about the
way Perl Shell processes the input

=cut

require Psh::Strategy;

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
	my $fnname= ${$_[0]};

	if ($fnname=~/^\?/) {
		return "debug $fnname";
	}
    return '';
}

sub execute {
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
}

1;
