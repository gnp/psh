use ExtUtils::MakeMaker;

my $pms= {};
my $pods= {};

open( FILE, "< MANIFEST");
while( <FILE>)
{
	chomp;
	next if $_ !~ /.pm$/;
	my $dest= $_;
	$dest=~ s/^lib/\$(INST_LIBDIR)/;
	$pms->{$_}=$dest;
}
close(FILE);

chdir 'doc';

my @tmp= glob('*.pod');
foreach (@tmp) {
	my $source= 'doc/'.$_;
	s/\.pod$//;
	my $dest= '$(INST_MAN1DIR)/'.$_.'.$(MAN1EXT)';
	$pods->{$source}=$dest;
}
chdir '..';


WriteMakefile (
	NAME         => 'psh',
	VERSION_FROM => 'psh',
	AUTHOR       => 'Gregor N. Purdy (gregor@focusresearch.com)',
	ABSTRACT     => 'Perl Shell',
	EXE_FILES    => [ qw(psh) ],
    PREREQ_PM    => {
					 'Cwd'   => '0',
					 'File::Spec' => '0',
					},
	MAN1PODS     => $pods,
    PM           => $pms,
	dist         => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' }
);

eval {
	require Term::ReadLine;
	require Term::ReadLine::Gnu;
};
if ($@) {
	eval {
		require Term::ReadLine::Perl;
	};
	if ($@) {
		print "We suggest you install Term::ReadLine::Gnu or Term::ReadLine::Perl to make psh more useful!\n";
	}
}

eval {
	require BSD::Resource;
};
if ($@) {
	print "The 'ulimit' command in psh will not work, unless you install BSD::Resource.\n";
}


#
# Does anyone know how to get MakeMaker to do this automatically ?
#

if ($^O =~ /win/) {
	print <<TEXT;
Please copy the 'share' directory to c:/psh after building and installing
psh!!!
}
print <<TEXT;
Do not forget to copy the 'share' directory to
/usr/share/psh or /usr/local/share/psh or ~/.psh after building and
installing !!!
TEXT
