package Psh::Locale::French;

use strict;
use vars qw($VERSION);
use locale;

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

BEGIN {
	my %sig_description = (
						   'TTOU' => 'téléscripteur sorti',
						   'TTIN' => 'téléscripteur entrent',
						   'KILL' => 'détruit',
						   'FPE'  => 'exception flottante de virgule',
						   'SEGV' => 'défaut de segmentation',
						   'PIPE' => 'cassée pipe',
						   'BUS'  => 'erreur de bus',
						   'ABRT' => 'interrompu',
						   'ILL'  => 'illégale instruction',
						   'TSTP' => 'arrêtez tapé au téléscripteur',
						   'INT'  => 'le caractère d'interruption a tapé'
						   );

	$Psh::text{sig_description}=\%sig_description;

	$Psh::text{done}='fait ';
	$Psh::text{terminated}='terminé';
	$Psh::text{stopped}='arrêté';
	$Psh::text{restart}='relancement';
	$Psh::text{foreground}='premier plan';
	$Psh::text{exec_failed}="Erreur (exec %1) échoué.\n";
    $Psh::text{simulate_perl_w}="En simulant -w commutez et strict\n";
	$Psh::text{perm_denied}="%2: %1: La permission a nié.\n";
	$Psh::text{no_such_dir}="%2: %1: Aucun un tel répertoire.\n";
	$Psh::text{no_such_builtin}="%2: %1: Aucun un tel builtin.\n";
	$Psh::text{readline_interrupted}="\nInterrompu!\n";
	$Psh::text{readline_error}="Readline n'a pas initialisé correctement:\n%1\n";
	$Psh::text{no_readline}="Aucun module de Readline disponible. Veuillez installer Term::Readline::Perl\n";
	$Psh::text{unalias_noalias}="unalias: `%1' n'est pas dit\n";
	$Psh::text{builtin_readline_header}="En utilisant Readline: %1, avec les dispositifs:\n";
	$Psh::text{no_jobcontrol}="Votre système ne supporte pas la gestion de tâche\n";
	$Psh::text{help_header}="psh supporte les commandes suivantes de builtin\n";
	$Psh::text{no_help}="Désolée, l'aide pour le builtin %1 n'est pas disponible\n";

	$Psh::text{prompt_expansion_error}=<<EOT;
%3: Avertissement: L'expansion d' '\\%1' dans le texte
prompt a rapporté le texte contenant '\\%2'. Retirant
l'ordre d'évasion de la substitution.
EOT

	$Psh::text{prompt_unknown_escape}="%2: Avertissement: \$Psh::prompt contient l'ordre d'évasion inconnu `\\%1'.\n";
	$Psh::text{no_libwin32}="libwin32 requis (disponible en tant que paquet d'CPAN ou avec la distribution d' ActivePerl).\n";
}


1;
__END__

=head1 NAME

Psh::Locale::French - containing translations for French locale

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 AUTHOR

Gregor N. Purdy, gregor@focusresearch.com

=head1 SEE ALSO


=cut
