
if ($^O eq 'MSWin32') {
	mkdir("/psh");
	system("xcopy share\\themes \psh /Y");
} else {
	if( -w '/') {
		print "Installing share files to $ARGV[0]/share/psh\n";
		system("mkdir -p $ARGV[0]/share/psh");
		system("cp -r share/themes $ARGV[0]/share/psh");
	} else {
		print "Installing share files to ~/.psh/share/psh\n";
		system("mkdir -p ~/.psh/share");
		system("cp -r share/themes ~/.psh/share");
	}
}

