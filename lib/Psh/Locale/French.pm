package Psh::Locale::French;

use strict;
use vars qw($VERSION);
use locale;

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

BEGIN {
	my %sig_description = (
						   'TTOU' => 'terminal (sortie)',
						   'TTIN' => 'terminal (entrée)',
						   'KILL' => 'arrêt (KILL)',
						   'FPE'  => 'exception (virgule flottante)',
						   'SEGV' => 'défaut de segmentation',
						   'PIPE' => 'tuyau (pipe) cassé',
						   'BUS'  => 'erreur de bus',
						   'ABRT' => 'avorté',
						   'ILL'  => 'instruction illégale',
						   'TSTP' => 'arrêt des entrées',
						   'INT'  => "interruption"
						   );

	$Psh::text{sig_description}=\%sig_description;

	$Psh::text{done}='fait ';
	$Psh::text{terminated}='terminé';
	$Psh::text{stopped}='arrêté';
	$Psh::text{restart}='relancement';
	$Psh::text{foreground}='premier plan';
	$Psh::text{exec_failed}="Erreur (exec %1) échoué.\n";
  $Psh::text{simulate_perl_w}="En simulant -w et 'strict'\n";
	$Psh::text{perm_denied}="%2 : %1 : Permission refusée.\n";
	$Psh::text{no_such_dir}="%2 : %1 : Répertoire introuvable.\n";
	$Psh::text{no_such_builtin}="%2 : %1 : commande interne (builtin) introuvable.\n";
	$Psh::text{readline_interrupted}="\nInterrompu !\n";
	$Psh::text{readline_error}="Readline n'a pas initialisé correctement :\n%1\n";
	$Psh::text{no_readline}="Readline non disponible. Veuillez installer Term::Readline::Perl\n";
	$Psh::text{old_gnu_readline}="La version de votre module Term::ReadLine::Gnu %1 devrait être au moins égale à 1.06. Veuillez le mettre à jour.\n";
	$Psh::text{unalias_noalias}="unalias : `%1' n'est pas exprimé\n";
	$Psh::text{builtin_readline_header}="Problème Readline %1 avec les dispositifs :\n";
	$Psh::text{no_jobcontrol}="Votre système ne supporte pas la gestion de tâche\n";
	$Psh::text{help_header}="psh supporte les commandes internes (builtin) suivantes :\n";
	$Psh::text{no_help}="Désolé, l'aide pour la commande interne (builtin) %1 n'est pas disponible\n";

	$Psh::text{prompt_expansion_error}=<<EOT;
%3: Avertissement : L'expansion d' '\\%1' (dans le 
prompt) a produit le texte '\\%2'. Je retire
cet échappement.
EOT

	$Psh::text{prompt_unknown_escape}="%2: Avertissement : \$Psh::prompt contient l'échappement inconnu `\\%1'.\n";
	$Psh::text{no_libwin32}="libwin32 requis (disponible sur CPAN en tant que paquet ou avec la distribution d'ActivePerl).\n";
}


1;
