use ExtUtils::MakeMaker;

my $pms= {};
my $pods= {};

sub MY::postamble {
	# to copy share files after installation
	'

install ::
	$(PERL) postinstall.pl $(SITEPREFIX)

';
}

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
	PM_FILTER    => 'grep -v \\"^\\#\\"',  # remove comments on install
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

