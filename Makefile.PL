use ExtUtils::MakeMaker;

WriteMakefile (
	NAME         => 'psh',
	VERSION_FROM => 'psh',
	AUTHOR       => 'Gregor N. Purdy (gregor@focusresearch.com)',
	ABSTRACT     => 'Simple Perl shell',
	EXE_FILES    => [ qw(psh) ],
	dist         => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' }
);

