use ExtUtils::MakeMaker;

WriteMakefile (
	NAME         => 'psh',
	VERSION_FROM => 'psh',
	AUTHOR       => 'Gregor N. Purdy (gregor@focusresearch.com)',
	ABSTRACT     => 'Perl Shell',
	EXE_FILES    => [ qw(psh) ],
	MAN1PODS     => { 'psh.pod' => '$(INST_MAN1DIR)/psh.$(MAN1EXT)' },
	PM           => {
		'lib/Psh.pm'            => '$(INST_LIBDIR)/Psh.pm',
		'lib/Psh/Completion.pm' => '$(INST_LIBDIR)/Psh/Completion.pm',
		'lib/Psh/Job.pm'        => '$(INST_LIBDIR)/Psh/Job.pm',
		'lib/Psh/Joblist.pm'    => '$(INST_LIBDIR)/Psh/Joblist.pm',
		'lib/Psh/Parser.pm'     => '$(INST_LIBDIR)/Psh/Parser.pm',
		'lib/Psh/Util.pm'       => '$(INST_LIBDIR)/Psh/Util.pm',
		'lib/Psh/Builtins.pm'   => '$(INST_LIBDIR)/Psh/Builtins.pm',
		'lib/Psh/Locale/Base.pm'    => '$(INST_LIBDIR)/Psh/Locale/Base.pm',
		'lib/Psh/Locale/Default.pm' => '$(INST_LIBDIR)/Psh/Locale/Default.pm',
		'lib/Psh/Locale/German.pm'  => '$(INST_LIBDIR)/Psh/Locale/German.pm'
			   },
	dist         => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' }
);

