package Psh::Locale::Italian;

use strict;
use vars qw($VERSION);
use locale;

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

BEGIN {
	my %sig_description = (
						   'TTOU' => 'uscita del TTY',
						   'TTIN' => 'input del TTY',
						   'KILL' => 'ucciso',
						   'FPE'  => 'eccezione della virgola mobile',
						   'SEGV' => 'difetto di segmentazione',
						   'PIPE' => 'tubo rotto',
						   'BUS'  => 'errore di bus',
						   'ABRT' => 'abbandonato',
						   'ILL'  => 'istruzione illegale',
						   'TSTP' => 'arrestarsi digitato al TTY',
						   'INT'  => 'carattere di interruzione digitato'
						   );

	$Psh::text{sig_description}=\%sig_description;

	$Psh::text{done}='fatto';
	$Psh::text{terminated}='terminato';
	$Psh::text{stopped}='arrestato';
	$Psh::text{restart}='riavviamento';
	$Psh::text{foreground}='priorità alta';
	$Psh::text{exec_failed}="Errore (exec %1) è venuto a mancare.\n"; # TODO: This doesn't seem right.
    $Psh::text{simulate_perl_w}="Simulando opzione -w e strict\n";
	$Psh::text{perm_denied}="%2: %1: Il permesso ha negato.\n";
	$Psh::text{no_such_dir}="%2: %1: Nessun tale indice.\n";
	$Psh::text{no_such_builtin}="%2: %1: Nessun tale builtin.\n";
	$Psh::text{readline_interrupted}="\nInterrotto!\n";
	$Psh::text{readline_error}="Readline non ha cominciato correttamente in su:\n%1\n";
	$Psh::text{no_readline}="Nessun modulo Readline disponibile. Installare prego Term::ReadLine::Perl\n";
	$Psh::text{unalias_noalias}="unalias: `%1' non sono altrimenti detto\n";
	$Psh::text{builtin_readline_header}="Usando Readline: %1, con le caratteristiche:\n";
	$Psh::text{no_jobcontrol}="Il vostro sistema non sostiene il controllo di lavoro\n";
	$Psh::text{help_header}="psh sostiene i seguenti comandi incorporati\n";
	$Psh::text{no_help}="Spiacente, l' aiuto per il builtin %1 non è disponibile\n";

	$Psh::text{prompt_expansion_error}=<<EOT;
%3: Avvertimento: L' espansione di '\\%1' nel messaggio
di richiamo ha reso il testo che contiene '\\%2'.
Rimuovendo sequenza di fuga dalla sostituzione
EOT

	$Psh::text{prompt_unknown_escape}="%2: Avvertimento: \$Psh::prompt contiene la sequenza di fuga sconosciuta `\\%1'.\n";
	$Psh::text{no_libwin32}="libwin32 ha richiesto (disponibile come gruppo CPAN o con distribuzione di ActivePerl).\n";
}


1;
