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
