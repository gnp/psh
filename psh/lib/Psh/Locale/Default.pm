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
	$psh::text{sig_description}=\%sig_description;
	$psh::text{done}='done';
	$psh::text{terminated}='terminated';
	$psh::text{stopped}='stopped';
	$psh::text{restart}='restart';
	$psh::text{foreground}='foreground';
	$psh::text{exec_failed}="Error (exec %1) failed.\n";
    $psh::text{simulate_perl_w}="Simulating -w switch and strict\n";
	$psh::text{perm_denied}="%2: %1: Permission denied.\n";
	$psh::text{no_such_dir}="%2: %1: No such directory.\n";
	$psh::text{readline_interrupted}="\nInterrupted!\n";
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
