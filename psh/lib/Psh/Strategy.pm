package Psh::Strategy;

use strict;
require Psh::Util;
require Psh::OS;

my %loaded=();
my %active=();
my @order=();

my @lvl1order=();
my @lvl2order=();
my @lvl3order=();

sub CONSUME_LINE { 1; }
sub CONSUME_WORDS { 2; } # currently unsupported
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
		eval "use $tmp;";
		if ($@) {
			print STDERR "$@";
			return undef;
		}
		eval {
			$obj= "Psh::Strategy::$name"->new();
		};
		if ($@ or !$obj) {
			print STDERR "$@";
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
	delete $active{$name} if $active{$name};
	regenerate_cache();
}

sub list {
	return @order;
}

sub available_list {
	my %result= ();
	foreach my $tmp (@INC) {
		my $tmpdir= Psh::OS::catdir($tmp,'Psh','Strategy');
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
	$active{$str_obj->name}=1;
	regenerate_cache();
}

sub regenerate_cache {
	@lvl1order= grep { $_ && $_->consumes() == CONSUME_LINE } @order;
	@lvl2order= grep { $_ && $_->consumes() == CONSUME_WORDS } @order;
	@lvl3order= grep { $_ && $_->consumes() == CONSUME_TOKENS } @order;
}

sub parser_strategy_list {
	return (\@lvl1order,\@lvl2order,\@lvl3order);
}

sub parser_return_objects {
	my @objs= map { get($_) } @_;
	my @lvl1= grep { $_->consumes() == CONSUME_LINE } @objs;
	my @lvl2= grep { $_->consumes() == CONSUME_WORDS } @objs;
	my @lvl3= grep { $_->consumes() == CONSUME_TOKENS } @objs;
	return (\@lvl1,\@lvl2,\@lvl3);
}

sub setup_defaults {
	require Psh::StrategyBunch;
	foreach my $name (qw(bang perl brace built_in perlfunc executable eval)) {
		my $tmpname= ucfirst($name);
		my $obj;
		eval {
			$obj= "Psh::Strategy::$tmpname"->new();
		};
		push @order, $obj;
		$loaded{$tmpname}= $obj;
		$active{$name}= 1;
	}
	if ($^O =~ /darwin/i) {
		splice(@order,@order-1,0, get('darwin_apps'));
		$active{darwin_apps}=1;
	}
	regenerate_cache();
}

sub active {
	my $name= shift;
	return $active{$name};
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
	return ();
}

sub consumes {
	die 'Abstract method';
}

sub applies {
	die 'Abstract method';
}

sub execute {
	die 'Abstract method';
}

1;

__END__

=head1 NAME

Psh::Strategy - a Perl Shell Evaluation Strategy (base class)

=head1 SYNOPSIS

  use Psh::Strategy;

=head1 DESCRIPTION

Psh::Strategy offers a procedural strategy list interface and a
base class for developing strategies.

=head1 PROCEDURAL STRATEGY LIST


  Psh::Strategy::list()

Returns a list of active Psh::Strategy objects.

  my $obj= Psh::Strategy::get('name')

Loads and initializes a certain Psh::Strategy object

  Psh::Strategy::add($obj [, $suggest_position])

Adds a strategy object to the list of active strategies

  Psh::Strategy::remove($name)

Removes a strategy

  @list= Psh::Strategy::available_list()

Lists available strategies

  my $pos= find($name)

Finds the position of the named strategy

  my $flag= active($name)

Returns true if the named strategy is currently active


=head1 DEVELOPING STRATEGIES

You have to inherit from Psh::Strategy and you MUST at least
override the functions C<consumes>, C<applies>, C<execute>.
You CAN also override the function C<runs_before>

=over 4

=item * consumes

Returns either CONSUME_LINE, CONSUME_WORDS, CONSUME_TOKENS.
CONSUME_LINE means you want to receive the whole input line
unparsed. CONSUME_WORDS means you want to receive the whole
input line tokenized (currenty unimplemented). CONSUME_TOKENS
means that you want to receive a sub-part of the line, tokenized
(this is probably what you want)

=item * applies

Returns undef if the strategy does not want to handle the input.
Returns a human-readable description if it wants to handle the input.

If you specified CONSUME_LINE, this method will be called as
  $obj->applies(\$inputline);

If you specified CONSUME_TOKENS, this method will be called as
  $obj->applies(\$inputline,\@tokens,$piped_flag)

=item * execute

Will be called as
  $obj->execute(\$inputline,\@tokens,$how,$piped_flag)

C<$how> is what the call to applies returned. If C<@tokens> is
not applicable an empty array will be supplied.

Your execute function should return an array of the form:

  ($evalcode, \@words, $forcefork, @return_val)

If C<$evalcode>, <@words> and <$forcefork> are undef, execution is finished
after this call and C<@return_val> will be used as return value.

But C<$evalcode> can also be a Perl sub - in which case it is evaluated
later on, or a string - in which case it's a filename of a program to
execute. C<@words> will then be used as arguments for the program.

C<$forcefork> may be used to force a C<fork()> call even for the perl
subs.

=item * runs_before

Returns a list of names of other strategies. It is guaranteed that
the evaluation strategy will be tried before those other named strategies
are tried.

=back

=cut
