use ExtUtils::MakeMaker;

$pms= {};

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


WriteMakefile (
	NAME         => 'psh',
	VERSION_FROM => 'psh',
	AUTHOR       => 'Gregor N. Purdy (gregor@focusresearch.com)',
	ABSTRACT     => 'Perl Shell',
	EXE_FILES    => [ qw(psh) ],
	MAN1PODS     => {
		   'doc/psh.pod' => '$(INST_MAN1DIR)/psh.$(MAN1EXT)',
		   'doc/pshdevel.pod' => '$(INST_MAN1DIR)/pshdevel.$(MAN1EXT)'},
    PM           => $pms,
	dist         => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' }
);

