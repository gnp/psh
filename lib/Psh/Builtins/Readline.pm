package Psh::Builtins::Readline;

use Psh::Util ':all';

=item * C<readline>

Prints out information about the current ReadLine module which is
being used for command line input. Very rudimentary at present, should 
be extended to allow rebinding, etc.

=cut

#
# TODO: How can we print out the current bindings in an
# ReadLine-implementation-independent way? We should allow rebinding
# of keys if Readline interface allows it, etc.
#
# Info:
# Bind a key: GNU: bind_key Perl: bind
#
# Other interesting stuff
# Perl: set(EditingMode) - vi or emacs keybindings
# Perl: set(TcshCompleteMode) - tcsh menu completion mode
# GNU: lots and lots...
#

sub bi_readline
{
	print_out_i18n('bi_readline_header',$Psh::term->ReadLine());

	my $featureref = $Psh::term->Features();

	for my $feechr (keys %{$featureref}) {
		print_out("  $feechr => ${$featureref}{$feechr}\n");
	}

	return (1,undef);
}

1;
