use ExtUtils::MakeMaker;

WriteMakefile (
	NAME         => 'psh',
	VERSION_FROM => 'psh',
	AUTHOR       => 'Gregor N. Purdy (gregor@focusresearch.com)',
	ABSTRACT     => 'Simple Perl shell',
	EXE_FILES    => [ qw(psh) ],
	PM           => {
		'Psh/Completion.pm' => '$(INST_LIBDIR)/Psh/Completion.pm',
		'Psh/Job.pm'        => '$(INST_LIBDIR)/Psh/Job.pm',
		'Psh/Joblist.pm'    => '$(INST_LIBDIR)/Psh/Joblist.pm',
		'Psh/Parser.pm'     => '$(INST_LIBDIR)/Psh/Parser.pm',
		'Psh/Locale/Base.pm'    => '$(INST_LIBDIR)/Psh/Locale/Base.pm',
		'Psh/Locale/Default.pm' => '$(INST_LIBDIR)/Psh/Locale/Default.pm',
		'Psh/Locale/German.pm'  => '$(INST_LIBDIR)/Psh/Locale/German.pm'
			   },
    PMLIBDIRS    => [ 'lib' ],
	dist         => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' }
);

