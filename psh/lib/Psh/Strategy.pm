package Psh::Strategy;

use strict;
require File::Spec;
require Psh::Util;
require Psh::OS;

my %loaded=();
my @order=();

sub new {
	my $proto= shift;
	my $class= ref($proto) || $proto;
	my $self = {};
	bless $self, $class;
	return $self;
}

sub get {
	my $name= shift;
	$name=ucfirst(lc($name));
	my $obj;
	unless (exists $loaded{$name}) {
		my $tmp='Psh::Strategy::'.$name;
		eval "require $tmp;";
		return undef if $@;
		eval {
			$obj= "Psh::Strategy::$name"->new();
		};
		if ($@ or !$obj) {
			return undef;
		}
		$loaded{$name}= $obj;
		return $obj;
	}
	return $loaded{$name};
}

sub remove {
	my $name= shift;
	@order= grep { $name ne $_ } @order;
	delete $loaded{$name};
}

sub list {
	return @order;
}

sub available_list {
	my %result= ();
	foreach my $tmp (@INC) {
		my $tmpdir= File::Spec->catdir($tmp,'Psh','Strategy');
		my @tmp= Psh::OS::glob('*.pm',$tmpdir);
		foreach my $strat (@tmp) {
			$strat=~s/\.pm$//;
			$strat=lc($strat);
			$result{$strat}=1;
		}
	}
	return sort keys %result;
}


1;

__END__

=head1 NAME

Psh::Strategy - a Perl Shell Evaluation Strategy (base class)

=head1 SYNOPSIS

  use Psh::Strategy;

=head1 DESCRIPTION

  Psh::Strategy->list()

Returns a list of active Psh::Strategy objects.

  my $obj= Psh::Strategy->get('name')

Loads and initializes a certain Psh::Strategy object

=cut
