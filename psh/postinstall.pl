
if ($^O eq 'MSWin32') {
	mkdir("/psh");
	system("xcopy share\\themes \\psh /Y");
	system("xcopy share\\complete \\psh /Y");
} else {
	my $where;

	if( -w '/') {
		$where= $ARGV[0]||$ARGV[1]||'/usr/local';
	} else {
		$where ='~/.psh';
	}
	print "Installing share files to $where/share/psh\n";
	system("mkdir -p $where/share/psh");
	system("cp -r share/themes $where/share/psh");
	system("cp -r share/complete $where/share/psh");
}

