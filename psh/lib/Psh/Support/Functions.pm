package Psh::Support::Functions;

require Psh;

my %functions=();

sub add_function {
	my $name= shift;
	my $text= shift;
	$functions{$name}= [map { $_."\n" } split /\n/, $text];
}

sub call_function {
	my $name= shift;
	Psh::process_variable($functions{$name}) if $functions{$name};
}

sub remove_function {
	my $name= shift;
	delete $functions{$name};
}

sub get_function {
	my $name= shift;
	return $functions{$name};
}

sub list {
	return sort keys %functions;
}

1;
