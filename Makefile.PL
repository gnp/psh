use ExtUtils::MakeMaker;

# Calculate which pods to install

my $pods={};

chdir 'docs';

my @tmp= glob('*.pod');
foreach (@tmp) {
    my $source= 'docs/'.$_;
    s/\.pod$//;
    my $dest= '$(INST_MAN1DIR)/'.$_.'.$(MAN1EXT)';
    $pods->{$source}=$dest;
}
chdir '..';

WriteMakefile(
	      NAME         => 'psh2',
	      VERSION_FROM => 'psh2',
	      AUTHOR       => 'Markus Peter (warp@spin.de)',
	      ABSTRACT     => 'Poly Shell',
	      EXE_FILES    => ['psh2'],
	      PREREQ_PM    => {
#			       'Term::ReadLine' => 0,
                               'Term::EditLine' => 0.05,
			       'Test::More' => 0,
			       'File::Glob' => 0,
                               'BSD::Resource' => 0,
			   },
	      MAN1PODS     => $pods,
              MAN3PODS     => {}, # don't create man file for CHANGES.pod
	      dist         => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' }
	     );
