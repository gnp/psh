package Psh::Builtins::Drives;

require Psh::Util;

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
		Psh::Util::print_out($_."\n") foreach @result;
	} else {
	}
	return (1,undef);
}

1;
