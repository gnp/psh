package Psh::Locale::Default;

#
# Main part of the module.
#

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
						   'TSTP' => 'stop typed at TTY',
						   'INT'  => 'interrupt character typed'
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
	$Psh::text{no_such_builtin}="%2: %1: No such builtin.\n";
	$Psh::text{readline_interrupted}="\nInterrupted!\n";
	$Psh::text{readline_error}="Readline did not start up properly:\n%1\n";
	$Psh::text{no_readline}="No Readline module available. Please install Term::ReadLine::Perl\n";
	$Psh::text{unalias_noalias}="unalias: `%1' not an alias\n";
	$Psh::text{builtin_readline_header}="Using Readline: %1, with features:\n";
	$Psh::text{no_jobcontrol}="Your system does not support job control\n";
	$Psh::text{help_header}="psh supports the following built in commands\n";
	$Psh::text{no_help}="Sorry, help for builtin %1 is not available\n";
	$Psh::text{prompt_expansion_error}=<<EOT;
%3: Warning: Expansion of '\\%1' in prompt string yielded
string containing '\\%2'. Stripping escape sequence from
substitution.
EOT
	$Psh::text{prompt_unknown_escape}="%2: Warning: \$Psh::prompt contains unknown escape sequence `\\%1'.\n";
	$Psh::text{no_libwin32}="libwin32 required (available as CPAN bundle or with ActivePerl distribution)\n";

}



1;
__END__

=head1 NAME

Psh::Locale::Default - containing translations for default locale


=head1 SYNOPSIS

  use Psh::Locale::Default;



=head1 DESCRIPTION

This module contains defaults for all of the internationalized
strings in the Perl Shell.


=head2 Translating Signal Names

The text below can be used with Babelfish to generate the signal
descriptions for translations.

  tty output
  
  tty input
  
  killed
  
  floating point exception
  
  segmentation fault
  
  broken pipe
  
  bus error
  
  aborted
  
  illegal instruction

  stop typed at TTY
  
  interrupt character typed
  
  
=head2 Translating Messages
 
The text below was used with Babelfish to generate the messages
for translations.
  
  done.
  
  terminated.
  
  stopped.
  
  restart.
  
  foreground.
  
  Error: "Foo" failed.
  
  Simulating option "W" and "strict".
  
  Permission denied.
  
  No such directory.
  
  No such builtin.
  
  Interrupted!
  
  "Readline" did not start up properly.
  
  No "Readline" module available. Please install "Term::ReadLine::Perl".
  
  "%1" is not an alias.
  
  Using "Readline": "%1", with features "X" and "Y".
  
  Your system does not support job control.
  
  "psh" supports the following built-in commands.
  
  Sorry, help for builtin %1 is not available.
  
  Warning: Expansion of "%1" in prompting message
  yielded text containing "%2" .
  Removing escape sequence from substitution.
  
  Warning: "Foo" contains unknown escape sequence.
  
  "libwin32" required (available as "CPAN" bundle or with "ActivePerl" distribution.
  

=head1 AUTHOR

Markus Peter, warp@spin.de


=head1 SEE ALSO

Psh::Locale::*


=cut
