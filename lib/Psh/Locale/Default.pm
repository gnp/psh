package Psh::Locale::Default;

#
# Main part of the module.
#

use strict;

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
# Misc texts
exec_failed=Error - Could not exec %1.
fork_failed=Error - Could not fork.
builtin_failed=Internal Error - Could not load builtin - %1
no_command=Command not found or syntax wrong: %1
simulate_perl_w=Simulating -w switch and strict
no_r_flag=If you intended to use a different rc file, please now use the -f switch.\n -r is now reserved for 'restricted mode'.
perm_denied=%2: %1: Permission denied.
no_such_dir=%2: %1: No such directory.
no_such_builtin=%2: %1: No such builtin.
no_such_strategy=%2: Unknown strategy '%1'.
no_jobcontrol=Your system does not support job control
interal_error=Internal psh error. psh would have died now.
input_incomplete=%2: End of input during incomplete expression %1
clueless=%2: Can't determine how to evaluate '%1'.
psh_echo_wrong=%1: WARNING: $Psh::echo is not a CODE reference or an ordinary scalar.
psh_result_array_wrong=%1: WARNING: $Psh::result_array is neither an ARRAY reference or a string.
cannot_read_script=%2: Cannot read script '%1'
cannot_open_script=%2: Cannot open script '%1'
redirect_file_missing=%2: Error: Filename missing after redirect '%1'.
evaluates_under=%1 evaluates under strategy %2 by %3

# Various builtins
unalias_noalias=unalias: '%1' not an alias
bi_readline_header=Using Readline %1, with features:
help_header=psh supports following built in commands
no_help=Sorry, help for builtin %1 is not available
usage_setenv=Usage: setenv <variable> <value>
usage_export=Usage: export <variable> [=] <value>\n       export <variable
usage_kill=Usage: kill <sig> <pid>| -l 
usage_delenv=Usage: delenv <var> [<var2> <var3> ...]
bi_export_tied=Variable \$%1 is already tied via %2, cannot export.
bi_kill_no_such_job=kill: No such job %1
bi_kill_no_such_jobspec=kill: Unknown job specification %1
bi_kill_error_sig=kill: Error sending signal %2 to process %1
bi_which_no_command=which: requires a command or command line as argument
bi_alias_none=No aliases.
bi_alias_cant_a=Cannot alias '-a'.
bi_jobs_none=No jobs.
bi_strategy_list=Following strategies are used:
bi_strategy_wrong_arg=Wrong argument for builtin strategy.
bi_strategy_notfound=Could not find strategy %1.
bi_fc_notfound=no command found.
bi_pshtoken_dumper=The pshtokenize command needs the Data::Dumper module!!

# Stuff for Job handling
done=done\
terminated=terminated\
stopped=stopped\
restart=restart\
foreground=foreground\
error=error\

# Readline
readline_interrupted}=\nInterrupted!
readline_error=Readline did not start up properly:\n%1
no_readline=No Readline module available. Please install Term::ReadLine::Perl
old_gnu_readline=Your version of Term::ReadLine::Gnu is %1 which is less than 1.06.  This is a known to be buggy version.  Please upgrade.\n

# Prompt stuff
prompt_wrong_type=%1: Warning: $Psh::prompt is neither a SCALAR nor a CODE reference.
prompt_unknown_escape=%2: Warning: $Psh::prompt or PS1/2 environment variables contain unknown escape sequence '\\%1'.
prompt_expansion_error=%3: Warning: Expansion of '\\%1' in prompt string yielded\nstring containing '%2'. Stripping escape sequence from\nsubstitution.

# Psh::OS::Win
no_libwin32=libwin32 required (available as CPAN bundle or with ActivePerl distribution

# Psh::OS::Unix
unix_received_strange_sig=Received SIG%1 - ignoring

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


