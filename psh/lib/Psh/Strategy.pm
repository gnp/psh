package Psh::Strategy;

use strict;
require File::Spec;
require Psh::Util;
require Psh::OS;

my %loaded=();
my @order=();

my @lvl1order=();
my @lvl2order=();
my @lvl3order=();

sub CONSUME_LINE { 1; }
sub CONSUME_WORDS { 2; }
sub CONSUME_TOKENS { 3; }

#####################################################################
#  Strategy List
#####################################################################

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
	@order= grep { $name ne $_->name } @order;
	delete $loaded{$name};
	regenerate_cache();
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

sub find {
	my $strategy= shift;
	$strategy=lc($strategy);
	for (my $i=0; $i<@order; $i++) {
		if ($order[$i]->name() eq $strategy) {
			return $i;
		}
	}
	return -1;
}

sub add {
	my $str_obj= shift;
	my $suggested_pos= shift;

	my $max= $#order; # add right before eval
	my $min= 0;

	my @tmp= $str_obj->runs_before();
	if (@tmp) {
		foreach (@tmp) {
			my $tmp= find($_);
			$max= $tmp if $tmp<$max and $tmp>=0;
		}
	}
	my $consumes= $str_obj->consumes();
	for (my $i=0; $i<=$max; $i++) {
		if ($order[$i]->consumes()<$consumes) {
			$min= $i if $i>$min;
			next;
		}
		if ($order[$i]->consumes()>$consumes) {
			$max= $i if $i<$max;
			last;
		}
	}
	my $pos=$max;
	if (defined $suggested_pos) {
		if ($pos>=$min and $pos<=$max) {
			$pos=$suggested_pos;
		}
	}
	splice(@order,$pos,0,$str_obj);
	regenerate_cache();
}

sub regenerate_cache {
	@lvl1order= grep { $_->consumes() == CONSUME_LINE } @order;
	@lvl2order= grep { $_->consumes() == CONSUME_WORDS } @order;
	@lvl3order= grep { $_->consumes() == CONSUME_TOKENS } @order;
}

sub parser_strategy_list {
	return (\@lvl1order,\@lvl2order,\@lvl3order);
}


#####################################################################
#  Base class for strategies
#####################################################################

sub new {
	my $proto= shift;
	my $class= ref($proto) || $proto;
	my %init= ();
	my $name;
	if ($class=~/^Psh::Strategy::(.*)$/) {
		$name= lc($1);
		return $loaded{$name} if exists $loaded{$name};
	} else {
		die 'Strategies must be in Psh::Strategy:: namespace!';
	}
	my $self = \%init;
	$self->{name}= $name;
	bless $self, $class;
	return $self;
}

sub name {
	return $_[0]->{name};
}

sub runs_before {
	return @{$_[0]->{runs_before}};
}

sub consumes {
	return $_[0]->{consumes};
}


1;

__END__

=head1 NAME

Psh::Strategy - a Perl Shell Evaluation Strategy (base class)

=head1 SYNOPSIS

  use Psh::Strategy;

=head1 DESCRIPTION

  Psh::Strategy::list()

Returns a list of active Psh::Strategy objects.

  my $obj= Psh::Strategy::get('name')

Loads and initializes a certain Psh::Strategy object

=cut
