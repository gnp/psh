package Psh::Builtins::Readline;

require Psh::Util;

=item * C<readline>

Prints out information about the current ReadLine module which is
being used for command line input. Very rudimentary at present, should 
be extended to allow rebinding, etc.

=cut

sub bi_readline
{
	Psh::Util::print_out_i18n('bi_readline_header',$Psh::term->ReadLine());

	my $featureref = $Psh::term->Features();

	for my $feechr (keys %{$featureref}) {
		Psh::Util::print_out("  $feechr => ${$featureref}{$feechr}\n");
	}

	return (1,undef);
}

1;
