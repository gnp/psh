use ExtUtils::MakeMaker;

WriteMakefile (
	NAME         => 'psh',
	VERSION_FROM => 'psh',
	AUTHOR       => 'Gregor N. Purdy (gregor@focusresearch.com)',
	ABSTRACT     => 'Simple Perl shell',
	EXE_FILES    => [ qw(psh) ],
	PM           => {
		'lib/Psh/Completion.pm' => '$(INST_LIBDIR)/Psh/Completion.pm',
		'lib/Psh/Job.pm'        => '$(INST_LIBDIR)/Psh/Job.pm',
		'lib/Psh/Joblist.pm'    => '$(INST_LIBDIR)/Psh/Joblist.pm',
		'lib/Psh/Parser.pm'     => '$(INST_LIBDIR)/Psh/Parser.pm',
		'lib/Psh/Locale/Base.pm'    => '$(INST_LIBDIR)/Psh/Locale/Base.pm',
		'lib/Psh/Locale/Default.pm' => '$(INST_LIBDIR)/Psh/Locale/Default.pm',
		'lib/Psh/Locale/German.pm'  => '$(INST_LIBDIR)/Psh/Locale/German.pm'
			   },
	dist         => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' }
);

