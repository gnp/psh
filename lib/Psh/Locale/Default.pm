package Psh::Locale::Default;

use strict;
use vars qw($VERSION);
use locale;

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

BEGIN {
	my %sig_description = (
						   'TTOU' => 'TTY output',
						   'TTIN' => 'TTY input',
						   'KILL' => 'killed',
						   'FPE'  => 'floating point exception',
						   'SEGV' => 'segmentation fault',
						   'PIPE' => 'broken pipe',
						   'BUS'  => 'bus error',
						   'ABRT' => 'aborted',
						   'ILL'  => 'illegal instruction',
						   'TSTP' => 'stop typed at TTY'
						   );
	$Psh::text{sig_description}=\%sig_description;
	$Psh::text{done}='done';
	$Psh::text{terminated}='terminated';
	$Psh::text{stopped}='stopped';
	$Psh::text{restart}='restart';
	$Psh::text{foreground}='foreground';
	$Psh::text{exec_failed}="Error (exec %1) failed.\n";
    $Psh::text{simulate_perl_w}="Simulating -w switch and strict\n";
	$Psh::text{perm_denied}="%2: %1: Permission denied.\n";
	$Psh::text{no_such_dir}="%2: %1: No such directory.\n";
	$Psh::text{readline_interrupted}="\nInterrupted!\n";
	$Psh::text{no_readline}="No Readline module available. Please install Term::ReadLine::Perl\n";
	$Psh::text{unalias_noalias}="unalias: `%1' not an alias\n";
	$Psh::text{builtin_readline_header}="Using Readline: %1, with features:\n";

}



1;
__END__

=head1 NAME

Psh::Locale::Default - containing translations for default locale

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 AUTHOR

Markus Peter, warp@spin.de

=head1 SEE ALSO


=cut
