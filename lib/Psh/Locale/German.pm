package Psh::Locale::German;

use strict;
use vars qw($VERSION);
use locale;

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

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


while(<DATA>) {
	next if /^\#/;
	chomp;
	if( /^([a-z_]+)=(.*)$/) {
		my $key= $1;
		my $val= $2;
		if( $val=~/\\$/) {
			$val=~ s/\\$//;
		} else {
			$val.="\n";
		}
		$val=~ s/\\n/\n/g;
		$val=~ s/\\(.)/$1/g;
		$Psh::text{$key}=$val;
	}
}

1;

__DATA__
exec_failed=Fehler (exec %1) fehlgeschlagen.
simulate_perl_w=Perl Warnings Modus und use strict werden simuliert.
perm_denied=%2: %1: Erlaubnis verweigert.
no_such_dir=%2: %1: Kein Verzeichnis mit diesem Namen.
no_such_builtin=%2: %1: Keine eingebaute Funktion mit diesem Namen
no_such_strategy=%2: Unbekannte Ausführungsstrategie '%1'.
no_jobcontrol=Ihr System unterstützt leider keine Job Control.
interal_error=Interner Psh Fehler - Psh würde nun eigentlich beendet.
input_incomplete=%2: Ende der Eingabe während des unvollständigen Ausdrucks '%1'
clueless=%2: Weiss nicht wie ich '%1' ausführen soll.
psh_echo_wrong=%1: Achtung: $Psh::echo ist weder ausführbarer Perl Code noch ein normaler Skalar.
psh_result_array_wrong=%1: Achtung: $Psh::result_array ist weder eine Referenz auf einen Array noch Text.
cannot_read_script=%2: Kann Skript '%1' nicht lesen
cannot_open_script=%2: Kann Skript '%1' nicht öffnen
redirect_file_missing=%2: Fehler: Dateiname fehlt nach Umleitung '%1'.
evaluates_under=%1 wird durch die Strategie %2 mit %3 ausgeführt

# Various builtins
unalias_noalias=unalias: '%1' ist kein Alias
bi_readline_header=Verwende Readline Modul %1, mit folgenden Eigenschaften:
help_header=psh unterstützt folgende eingebaute Kommandos:
no_help=Hilfe für Kommando %1 ist leider nicht verfügbar.
usage_setenv=Verwendung: setenv <variable> <value>
usage_export=Verwendung:\nexport <variable> [=] <value>\nexport <variable
usage_kill=Verwendung: kill <sig> <pid>| -l 
bi_export_tied=Variable \$%1 ist bereits an %2 gebunden, kann nicht exportiert werden.
bi_kill_no_such_job=kill: Job %1 unbekannt
bi_kill_no_such_jobspec=kill: Unbekannte Jobspezifikation %1
bi_kill_error_sig=kill: Fehler beim Senden von Signal %2 an Prozess %1
bi_which_no_command=which: benötigt ein Argument
bi_alias_none=Keine Aliase.
bi_alias_cant_a=Es ist nicht erlaubt einen Alias mit dem Namen '-a' anzulegen.
bi_jobs_none=Keine Jobs.

# Stuff for Job handling
done=erledigt\
terminated=abgebrochen\
stopped=gestoppt\
restart=weiter\
foreground=Vordergrund\

# Readline
readline_interrupted}=\nAbgebrochen!
readline_error=Readline wurde nicht richtig gestartet:\n%1
no_readline=Kein Readline Modul verfügbar. Bitte installieren Sie Term::ReadLine::Perl


# Prompt stuff
prompt_wrong_type=%1: Warnung: $Psh::prompt ist weder ein Perl Skalar noch ausführbarer Perl Code.
prompt_unknown_escape=%2: Warnung: $Psh::prompt oder PS1/2 Umgebungsvariable enthält unbekannte Prompt Variable '\\%1'.
prompt_expansion_error=%3: Achtung: Prompt Variable '\\%1' wird ignoriert da sie aufgelöst '\\%2' ergab.

# Psh::OS::Win
no_libwin32=libwin32 Library benötigt (vorhanden als CPAN Bundle oder ausgeliefert mit ActiveState Perl)

# Psh::OS::Unix
unix_received_strange_sig=Signal SIG%1 wurde empfangen - wird ignoriert

__END__

=head1 NAME

Psh::Locale::German - containing translations for German locales

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 AUTHOR

Markus Peter, warp@spin.de

=head1 SEE ALSO


=cut
