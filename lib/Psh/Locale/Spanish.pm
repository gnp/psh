package Psh::Locale::Spanish;

use strict;
use vars qw($VERSION);
use locale;

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

BEGIN {
	my %sig_description = (
						   'TTOU' => 'terminal entrada',
						   'TTIN' => 'terminal salida',
						   'KILL' => 'matado',
						   'FPE'  => 'anomalía flotante de la coma',
						   'SEGV' => 'incidente de la segmentación',
						   'PIPE' => 'tubo roto',
						   'BUS'  => 'error de bus',
						   'ABRT' => 'abortado',
						   'ILL'  => 'instrucción illegal',
						   'TSTP' => 'pare pulsado en la terminal',
						   'INT'  => 'el carácter de interrupción pulsó'
						   );

	$Psh::text{sig_description}=\%sig_description;

	$Psh::text{done}='hecho';
	$Psh::text{terminated}='terminado';
	$Psh::text{stopped}='parado';
	$Psh::text{restart}='relanzar';
	$Psh::text{foreground}='primero plano';
	$Psh::text{exec_failed}="Error (exec %1) dejado.\n";
    $Psh::text{simulate_perl_w}="Simulando opción -w y `strict'\n";
	$Psh::text{perm_denied}="%2: %1: Permiso negado.\n";
	$Psh::text{no_such_dir}="%2: %1: Ningún tal directorio.\n";
	$Psh::text{no_such_builtin}="%2: %1: Ningún tal builtin.\n";
	$Psh::text{readline_interrupted}="\nInterrumpido!\n";
	$Psh::text{readline_error}="Readline no empezó correctamente:\n%1\n";
	$Psh::text{no_readline}="Ningún módulo de ReadLine disponible. Instale por favor Term::ReadLine::Perl.\n";
	$Psh::text{unalias_noalias}="unalias: `%1' no alias\n";
	$Psh::text{builtin_readline_header}="Usando Readline: %1, con las características:\n";
	$Psh::text{no_jobcontrol}="Su sistema no utiliza control de trabajo\n";
	$Psh::text{help_header}="psh utiliza siguientes los comandos `built-in'\n";
	$Psh::text{no_help}="Apesadumbrada, la ayuda para el `built-in' %1 no está disponible\n";

	$Psh::text{prompt_expansion_error}=<<EOT;
%3: Alerta: Extensión de '\\%1' en guía mensaje produjo
mensaje conteniendo '\\%2'. Quitando secuencia de escape del
resultado.
EOT

	$Psh::text{prompt_unknown_escape}="%2: Alerta: \$Psh::prompt contiene una secuencia de escape desconocida `\\%1'.\n";
	$Psh::text{no_libwin32}="libwin32 requerido (disponible como manojo del CPAN o con la distribución ActivePerl).\n";
}


1;
__END__

=head1 NAME

Psh::Locale::Spanish - containing translations for Spanish locale

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 AUTHOR

Gregor N. Purdy, gregor@focusresearch.com

=head1 SEE ALSO


=cut
