package Psh::Locale::German;

use strict;
use vars qw($VERSION);
use locale;

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

BEGIN {
	my %sig_description = (
							'TTOU' => 'Terminalausgabe',
							'TTIN' => 'Terminaleingabe',
							'KILL' => 'gewaltsam beendet',
							'FPE'  => 'Fließkommaausnahme',
							'SEGV' => 'Unerlaubter Speicherzugriff',
							'PIPE' => 'Pipe unterbrochen',
							'BUS'  => 'Bus Fehler',
							'ABRT' => 'Unterbrochen',
							'ILL'  => 'Illegale Anweisung',
							'TSTP' => 'von Benutzer unterbrochen'
							);

	$Psh::text{sig_description}=\%sig_description;

    $Psh::text{done}='getan';
    $Psh::text{terminated}='abgebrochen';
    $Psh::text{stopped}='gestoppt';
    $Psh::text{restart}='wiederanlauf';
    $Psh::text{foreground}='vordergrund';
    $Psh::text{exec_failed}="Fehler (exec %1) fiel aus.\n";
    $Psh::text{simulate_perl_w}="Option -w und strict simulieren\n";
    $Psh::text{perm_denied}="%2: %1: Erlaubnis verweigerte.\n";
    $Psh::text{no_such_dir}="%2: %1: Kein solches Verzeichnis.\n";
    $Psh::text{no_such_builtin}="%2: %1: Kein solches builtin.\n";
    $Psh::text{readline_interrupted}="\nUnterbrochen!\n";
    $Psh::text{readline_error}="Readline begann nicht oben richtig:\n%1\n";
    $Psh::text{no_readline}="Kein modul Readline vorhanden. Installieren sie bitte Term::ReadLine::Perl\n";
    $Psh::text{unalias_noalias}="unalias: `%1' ist nicht alias\n";
    $Psh::text{builtin_readline_header}="Readline Verwenden: %1, mit Eigenschaften:\n";
    $Psh::text{no_jobcontrol}="Ihr system unterstützt nicht jobsteuerung\n";
    $Psh::text{help_header}="psh unterstützt die folgenden residenten Befehle\n";
    $Psh::text{no_help}="Traurig, ist Hilfe für builtin %1 nicht vorhanden\n";

    $Psh::text{prompt_expansion_error}=<<EOT;
%3: Warnmeldung: Expansion '\\%1' in auffordernmeldung erbrachte
den text, der '\\%2' enthält. Löschen von Entweichenreihenfolge
vom Ersatz. 
EOT

    $Psh::text{prompt_unknown_escape}="%2: Warnmeldung: \$Psh::prompt enthält unbekannte Entweichenreihenfolge `\\%1'.\n";
    $Psh::text{no_libwin32}="libwin32 benötigte (vorhanden als CPAN-bündel oder mit ActivePerl-verteilung)\n";
}


1;
__END__

=head1 NAME

Psh::Locale::German - containing translations for German locales

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 AUTHOR

Markus Peter, warp@spin.de

=head1 SEE ALSO


=cut
