package Psh::Builtins::Drives;
use strict;

use Psh::Util ':all';

=item * C<drives>

Prints a list of the available drives on Windows or nothing on windows

=cut


sub bi_drives
{
	if ($^O eq 'MSWin32') {
		# I do not particularly like platform dependant code here
		# On the other hand I also dislike filling the Psh::OS module
		# with stuff for highly optional builtins
		my @result=();
		eval "use Win32::NetAdmin;";
		Win32::NetAdmin::GetServerDisks("",\@result);
		print_out($_."\n") foreach @result;
	} else {
	}
	return undef;
}

1;

# Local Variables:
# mode:perl
# tab-width:4
# indent-tabs-mode:t
# c-basic-offset:4
# perl-label-offset:0
# perl-indent-level:4
# cperl-indent-level:4
# cperl-label-offset:0
# End:

