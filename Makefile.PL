use ExtUtils::MakeMaker;

# Calculate which pods to install

my $pods;

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
	      AUTHOR       => 'Gregor N. Purdy (gregor@focusresearch.com) and Markus Peter (warp@spin.de)',
	      ABSTRACT     => 'Poly Shell',
	      EXE_FILES    => ['psh2'],
	      PREREQ_PM    => {
			       'Term::ReadLine' => 0,
			       'Test::More' => 0,
			       'File::Glob' => 0,
			   },
	      MAN1PODS     => $pods,
	      dist         => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' }
	     );

# We override libscan so Emacs backups are excluded
sub MY::libscan {
    my( $self, $path) = @_;
    return $path if $path =~ /psh2$/;
    return '' if $path =~ m:\b(RCS|CVS|SCCS)\b: or $path=~ m/\~\b/ or
      $path =~ m/\~$/;
    return '' if $path !~ m:\.pm\b:;
    print STDERR "$path\n";
    $path;
}
