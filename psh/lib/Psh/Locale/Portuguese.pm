package Psh::Locale::Portuguese;

use strict;
use locale;

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

BEGIN {
	my %sig_description = (
						   'TTOU' => 'saída do TTY',
						   'TTIN' => 'entrada do TTY',
						   'KILL' => 'matado',
						   'FPE'  => 'exceção do ponto flutuando',
						   'SEGV' => 'falha da segmentação',
						   'PIPE' => 'tubulação quebrada',

                                      # TODO: This is probably not correct. It probably means
                                      # bus as in schoolbus or city bus.
						   'BUS'  => 'erro de barra-ônibus',

						   'ABRT' => 'abortado',
						   'ILL'  => 'instrução ilegal',
						   'TSTP' => 'pare datilografado no TTY',
						   'INT'  => 'o caráter de interrupção datilografou'
						   );

	$Psh::text{sig_description}=\%sig_description;

	$Psh::text{done}='feito';
	$Psh::text{terminated}='terminado';
	$Psh::text{stopped}='parado';
	$Psh::text{restart}='reinício';
	$Psh::text{foreground}='primeiro plano';
	$Psh::text{exec_failed}="Erro (exec %1) falhou.\n";
    $Psh::text{simulate_perl_w}="Simulando a opção -w e strict\n";
	$Psh::text{perm_denied}="%2: %1: Permissão negada.\n";
	$Psh::text{no_such_dir}="%2: %1: Nenhum tal diretório.\n";
	$Psh::text{no_such_builtin}="%2: %1: Nenhum tal builtin.\n";
	$Psh::text{readline_interrupted}="\nInterrompido!\n";
	$Psh::text{readline_error}="Readline não começou acima corretamente:\n%1\n";
	$Psh::text{no_readline}="Nenhum módulo de Readline disponível. Instale por favor Term::ReadLine::Perl\n";
	$Psh::text{unalias_noalias}="unalias: `%1' não é aliás\n";
	$Psh::text{builtin_readline_header}="Usando Readline: %1, com características:\n";
	$Psh::text{no_jobcontrol}="Seu sistema não suporta o controle de trabalho\n";
	$Psh::text{help_header}="psh suporta os seguintes comandos internos\n";
	$Psh::text{no_help}="Pesarosa, a ajuda para o builtin %1 não está disponíve\n";


	$Psh::text{prompt_expansion_error}=<<EOT;
%3: Aviso: A expansão de '\\%1' na mensagem de alerta
rendeu o texto que contem '\\%2'. Removendo a seqüência
de escape da substituição.
EOT

	$Psh::text{prompt_unknown_escape}="%2: Aviso: \$Psh::prompt contem seqüência de escape desconhecida `\\%1'.\n";
	$Psh::text{no_libwin32}="libwin32 requerido (disponível como o pacote de CPAN ou com distribuição de ActivePerl).\n";
}


1;
