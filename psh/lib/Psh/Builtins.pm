#! /usr/local/bin/perl -w

=head1 NAME

Psh::Builtins - package for Psh builtins, possibly loading them as needed

=head1 SYNOPSIS

  use Psh::Builtins;

=head1 DESCRIPTION

Psh::Builtins currently contains only the hardcoded builtins of Perl Shell,
but may later on be extended to load them on the fly from separate
modules.

=head2 Builtins

=over 4

=cut

package Psh::Builtins;

###############################################################
# Short description:
# (I included it here because it's not supposed to be in the
#  user documentation)
#
# There are x types of functions in this package
# 1) bi_builtin functions in Psh::Builtins - these are
#    the builtin definitions
# 2) bi_builtin functions in Psh::Builtins::Fallback - these
#    are last resort fallback builtins for non-unix platforms
#    so psh can offer minimum functionality for them even without
#    stuff like GNU fileutils etc.
# 3) cmpl_builtin functions in Psh::Builtins - these are
#    functions called by the TAB completer to complete text for
#    the builtins. They return a list. The first element of the
#    list is a flag which specifies wether the completions should
#    add to the standard completions or replace them. See the code
#    for more information
# 4) Utility and internal functions
###############################################################

use strict;
use vars qw($VERSION);

use Cwd qw(:DEFAULT chdir);
use Config;
use Psh::Util qw(:all print_list);
use Psh::OS;
use Pod::Text;
use File::Spec;

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

my $PS=$Psh::OS::PATH_SEPARATOR;

%Psh::array_exports=('PATH'=>$PS,'CLASSPATH'=>$PS,'LD_LIBRARY_PATH'=>$PS,
					 'FIGNORE'=>$PS,'CDPATH'=>$PS);

#
# string _do_setenv(string command)
#
# command is of the form "VAR VALUE" or "VAR = VALUE" or "VAR"; sets
# $ENV{VAR} to "VALUE" in the first two cases, or to "$VAR" in the
# third case unless $VAR is undefined. Used by the setenv and export
# builtins. Returns VAR (which is a string with no $).

sub _do_setenv
{
	my $arg = shift;
	if( $arg=~ /^\s*(\w+)(\s+|\s*=\s*)(.+)/ ) {
		my $var= $1;
		my $value= $3;
		if( $value=~ /^\'(.*)\'\s*$/ ) {
			# If single quotes were used, do not interpret
			# variables
			$ENV{$var}=$1;
		} else {
			$var =~ s/^\$//;
			# Use eval so that variables may appear on RHS
			# ($value); use protected_eval so that lexicals
			# in this file don't shadow package variables
			Psh::protected_eval("\$ENV{$var}=\"$value\"", 'do_setenv');
		}
		return $var;
	} elsif( $arg=~ /(\w+)/ ) {
		my $var= $1;
		$var =~ s/^\$//;
		Psh::protected_eval("\$ENV{$var}=\$$var if defined(\$$var);",
			       'do_setenv');
		return $var;
	}
	return '';
}

$Psh::Builtins::help_setenv = '

=item * C<setenv NAME [=] VALUE>

Sets the environment variable NAME to VALUE.

=cut ';

sub bi_setenv
{
	my $var = _do_setenv(@_);
	print_error_i18n('usage_setenv') if !$var;
	return undef;
}

$Psh::Builtins::help_export = '

=item * C<export VAR [=VALUE]>

Just like setenv, below, except that it also ties the variable (in the
Perl sense) so that subsequent changes to the variable automatically
affect the environment. Variables who are lists and appear in
C<%Psh::array_exports> will also by tied to the array of the same name.
Note that the variable must be specified without any Perl specifier
like C<$> or C<@>.

=cut ';

sub bi_export
{
	my $var = _do_setenv(@_);
	if ($var) {
		my @result = Psh::protected_eval("tied(\$$var)");
		my $oldtie = $result[0];
		if (defined($oldtie)) {
			if (ref($oldtie) ne 'Env') {
				print_warning_i18n('bi_export_tied',$var,$oldtie);
			}
		} else {
			Psh::protected_eval("use Env '$var';");
			if( exists($Psh::array_exports{$var})) {
				eval "use Env::Array;";
				if( ! @$) {
					Psh::protected_eval("use Env::Array qw($var $Psh::array_exports{$var});",'hide');
				}
			}
		}
	} else {
		print_error_i18n('usage_export');
	}
	return undef;
}


$Psh::Builtins::help_cd = '

=item * C<cd DIR>

Change the working directory to DIR or home if DIR is not specified.
The special DIR "-" is interpreted as "return to the previous
directory".

=cut ';


{
	my $last_dir= '.'; # By default 'cd -' won't change directory at all.
	$ENV{OLDPWD}= $last_dir;

	sub bi_cd
	{
		my $in_dir = shift || Psh::OS::get_home_dir();
		my $dirpath= $ENV{CDPATH} || '.';

		foreach my $cdbase (split $PS,$dirpath) {
			my $dir= $in_dir;
			$dir = $last_dir if $dir eq '-';
			if( $cdbase eq '.' ||
				File::Spec->file_name_is_absolute($dir)) {
				$dir = Psh::Util::abs_path($dir);
			} else {
				$dir = Psh::Util::abs_path(File::Spec->catdir($cdbase,$dir));
			}
		
			if ((-e $dir) and (-d _)) {
				if (-x _) {
					$last_dir = cwd;
					$ENV{OLDPWD}= $last_dir;
					chdir $dir;
					return 0;
				} else {
					print_error_i18n('perm_denied',$in_dir,$Psh::bin);
					return 1;
				}
			}
		}
		print_error_i18n('no_such_dir',$in_dir,$Psh::bin);
		return 1;
	}

    sub cmpl_cd {
		my( $text, $pre) = @_;
		return 1,Psh::Completion::cmpl_directories($pre.$text);
	}
}


$Psh::Builtins::help_kill = '

=item * C<kill [SIGNAL] [%JOB | PID] | -l>

Send SIGNAL (which defaults to TERM) to the given process, specified
either as a job (%NN) or as a pid (a number).

=cut ';

sub bi_kill
{
	if( ! Psh::OS::has_job_control()) {
		print_error_i18n('no_jobcontrol');
		return undef;
	}

	my @args = split(' ',$_[0]);
	my ($sig, $pid, $job);

	if (scalar(@args) == 1 &&
		$args[0] eq '-l') {
		print_out($Config{sig_name}."\n");
		return undef;
	} elsif (scalar(@args) == 1) {
		$pid = $args[0];
		$sig = 'TERM';
	} elsif (scalar(@args) == 2) {
		($sig, $pid) = @args;
	} else {
		print_error_i18n('usage_kill');
		return 1;
	}

	if ($pid =~ m|^%(\d+)$|) {
		my $temp = $1 - 1;

		$job= $Psh::joblist->find_job($temp);
		if( !defined($job)) {
			print_error_i18n('bi_kill_no_such_job',$pid);
			return 1;
		}

		$pid = $job->{pid};
	}

	if ($pid =~ m/\D/) {
		print_error_i18n('bi_kill_no_such_jobspec',$pid);
		return 1;
	}

	if ($sig ne 'CONT' and $Psh::joblist->job_exists($pid)
		and !(($job=$Psh::joblist->get_job($pid))->{running})) {
		#Better wake up the process so it can respond to this signal
		$job->continue;
	}

	if (CORE::kill($sig, $pid) != 1) {
		print_error_i18n('bi_kill_error_sig',$pid,$sig);
		return 1;
	}

	if ($sig eq 'CONT' and $Psh::joblist->job_exists($pid)) {
		$Psh::joblist->get_job($pid)->{running}=1;
	}

	return 0;
}

# Completion function for kill
sub cmpl_kill {
	my( $text, undef, $starttext) = @_;

	return (1) if( $starttext=~ /^kill\s+\w+\s+/);
	return (1,grep { Psh::Util::starts_with($_,$text) } 
	         split / /, $Config{sig_name});
}

$Psh::Builtins::help_which = '

=item * C<which COMMAND-LINE>

Describe how B<psh> will execute the given COMMAND-LINE, under the
current setting of C<$Psh::strategies>.

=cut ';

sub bi_which
{
	my $line   = shift;

	if (!defined($line) or $line eq '') {
		print_error_i18n('bi_which_no_command');
		return 1;
	}


	print_debug("[which $line]\n");

	my @words= Psh::Parser::std_tokenize($line);
	foreach my $strat (@Psh::unparsed_strategies) {
		if (!defined($Psh::strategy_which{$strat})) {
			print_warning_i18n('no_such_strategy',$strat,'which');
			next;
		}

		my $how = &{$Psh::strategy_which{$strat}}(\$line,\@words);

		if ($how) {
			print_out_i18n('evaluates_under',$line,$strat,$how);
			return 0;
		}
	}


	my @words= Psh::Parser::decompose(
							'(\s+|\||;|\&\d*|[0-9&]*>|[0-9&]*<|\\|=)',
							$line, undef, 1,
							{"'"=>"'","\""=>"\"","{"=>"}"});
	# TODO: The special rules are missing so this is not really correct

	my $line= join ' ', @words;
	foreach my $strat (@Psh::strategies) {
		if (!defined($Psh::strategy_which{$strat})) {
			print_warning_i18n('no_such_strategy',$strat,'which');
			next;
		}

		my $how = &{$Psh::strategy_which{$strat}}(\$line,\@words);

		if ($how) {
			print_out_i18n('evaluates_under',$line,$strat,$how);
			return 0;
		}
	}

	print_warning_i18n('clueless',$line,'which');
	return 1;
}


$Psh::Builtins::help_alias = '

=item * C<alias [NAME [=] REPLACEMENT]> 

Add C<I<NAME>> as a built-in so that NAME <REST_OF_LINE> will execute
exactly as if REPLACEMENT <REST_OF_LINE> had been entered. For
example, one can execute C<alias ls ls -F> to always supply the B<-F>
option to "ls". Note the built-in is defined to avoid recursion
here.

With no arguments, prints out a list of the current aliases.
With only the C<I<NAME>> argument, prints out a definition of the
alias with that name.

=cut ';

# Cannot use "static" variables anymore as I do not know how to
# lookup the function then
my %aliases = ();
	
sub bi_alias
{
	my $line = shift;
	my ($command, $firstDelim, @rest) = Psh::Parser::decompose('([ \t\n=]+)', $line, undef, 0);
	my $text = join('',@rest); # reconstruct everything after the
	# first delimiter, sans quotes
	if (($command eq "") && ($text eq "")) {
		my $wereThereSome = 0;
		for $command (sort keys %aliases) {
			my $aliasrhs = $aliases{$command};
			$aliasrhs =~ s/\'/\\\'/g;
			print_out("alias $command='$aliasrhs'\n");
			$wereThereSome = 1;
		}
		if (!$wereThereSome) {
			print_out_i18n('bi_alias_none');
		}
	} elsif( $text eq '') {
		my $aliasrhs = $aliases{$command};
		$aliasrhs =~ s/\'/\\\'/g;
		print_out("alias $command='$aliasrhs'\n");
	} elsif ($text eq '-a') {
		print_error_i18n('bi_alias_cant_a');
	} else {
		print_debug("[[ Aliasing '$command' to '$text']]\n");
		# my apologies for the gobbledygook
		my $string_to_eval = "\$Psh::built_ins{'$command'} = "
			. " sub { local \$Psh::built_ins{'$command'} = undef; Psh::evl(q($text) .' '. shift); }";
		print_debug("[[ alias evaluating: $string_to_eval ]]\n");
		eval($string_to_eval);
		if ($@) { print_error($@); return 1; }
		# if successful, record the alias
		$aliases{$command} = $text;
	}
	return 0;
}

$Psh::Builtins::help_unalias = '

=item * C<unalias NAME | -a | all]>

Removes the alias with name <C<I<NAME>> or all aliases if either <C<I<-a>>
(for bash compatibility) or <C<I<all>> is specified.

=cut ';

sub bi_unalias {
	my $name= shift;
	if( ($name eq '-a' || $name eq 'all') and !_is_aliased($name) ) {
		$Psh::built_ins= ();
		for my $command (keys %aliases) {
		  delete($Psh::built_ins{$command});
		}
		%aliases= ();
	} elsif( _is_aliased($name)) {
		delete($aliases{$name});
		delete($Psh::built_ins{$name});
	} else {
		print_error_i18n('unalias_noalias', $name);
		return 1;
	}
	return 0;
}


sub cmpl_unalias {
	my $text= shift;
	return (1,grep { Psh::Util::starts_with($_,$text) } get_alias_commands());
}


# 
# bool _is_aliased( string COMMAND )
#
# returns TRUE if COMMAND is aliased:

sub _is_aliased {
       my $command = shift;
       if (exists($aliases{$command})) { return 1; }
       return 0;
}

$Psh::Builtins::help_fg = '

=item * C<fg JOB>

Bring a job into the foreground. If JOB is omitted, uses the
highest-numbered stopped job, or, failing that, the highest-numbered job.
JOB may either be a job number or a word that occurs in the command used to create the job.

=cut ';

sub bi_fg
{
	my $arg = shift;

	if( ! Psh::OS::has_job_control()) {
		print_error_i18n('no_jobcontrol');
		return undef;
	}

	$arg = -0 if (!defined($arg) or ($arg eq ''));
	$arg =~ s/\%//;
	if( $arg =~ /[^0-9]/) {
		Psh::evl($arg);
		return undef;
	}

	Psh::OS::restart_job(1, $arg - 1);

	return undef;
}


$Psh::Builtins::help_bg = '

=item * C<bg [JOB]>

Put a job into the background. If JOB is omitted, uses the
highest-numbered stopped job, if any.

=cut ';

sub bi_bg
{
	my $arg = shift;

	if( ! Psh::OS::has_job_control()) {
		print_error_i18n('no_jobcontrol');
		return undef;
	}


	$arg = 0 if (!defined($arg) or ($arg eq ''));
	$arg =~ s/\%//;
	if( $arg =~ /[^0-9]/) {
		Psh::evl($arg.' &');
		return undef;
	}

	Psh::OS::restart_job(0, $arg - 1);

	return undef;
}


$Psh::Builtins::help_jobs = '

=item * C<jobs>

List the currently running jobs.

=cut ';

sub bi_jobs {
	if( ! Psh::OS::has_job_control()) {
		print_error_i18n('no_jobcontrol');
		return undef;
	}


	my $result = '';
	my $job;
	my $visindex=1;

	$Psh::joblist->enumerate;

	while( ($job=$Psh::joblist->each)) {
		my $pid      = $job->{pid};
		my $command  = $job->{call};
	    
		$result .= "[$visindex] $pid $command";

		if ($job->{running}) { $result .= "\n"; }
		else                 { $result .= ' ('.$Psh::text{stopped}.")\n"; }
		$visindex++;
	}

	if (!$result) { print_out_i18n('bi_jobs_none'); }
	else {
		print_out($result);
	}

	return undef;
}

$Psh::Builtins::help_exit = '

=item * C<exit>

Exit out of the shell.

=cut ';

#
# TODO: What if a string is passed in?
#


sub bi_exit
{
	my $result = shift;
	$result = 0 unless defined($result) && $result;

	if ($Psh::save_history && $Psh::readline_saves_history) {
		$Psh::term->WriteHistory($Psh::history_file);
	}
	
	my $file= File::Spec->catfile(Psh::OS::get_home_dir(),".${Psh::bin}_logout");
	if( -r $file) {
		process_file(abs_path($file));
	}

	Psh::OS::exit($result);
}


$Psh::Builtins::help_source = '

=item * C<source FILE> [or C<. FILE>]

Read and process the contents of the given file as a sequence of B<psh>
commands.

=cut ';

sub bi_source
{
	local $Psh::echo = 0;

	for my $file (split(' ',$_[0])) { Psh::process_file(abs_path($file)); }

	return undef;
}


$Psh::Builtins::help_readline = '

=item * C<readline>

Prints out information about the current ReadLine module which is
being used for command line input. Very rudimentary at present, should 
be extended to allow rebinding, etc.

=cut ';

#
# TODO: How can we print out the current bindings in an
# ReadLine-implementation-independent way? We should allow rebinding
# of keys if Readline interface allows it, etc.
#

sub bi_readline
{
	print_out_i18n('bi_readline_header',$Psh::term->ReadLine());

	my $featureref = $Psh::term->Features();

	for my $feechr (keys %{$featureref}) {
		print_out("  $feechr => ${$featureref}{$feechr}\n");
	}

	return undef;
}

$Psh::Builtins::help_help = '

=item * C<help [COMMAND]>

If COMMAND is specified, print out help on it; otherwise print out a list of 
B<psh> builtins.

=cut ';

sub bi_help
{
	my $arg= shift;
	if( $arg) {
		my $tmp= eval '$Psh::Builtins::help_'.$arg;
		if( $tmp ) {
			Psh::OS::display_pod("=over 4\n".$tmp."\n=back\n");
		} else {
			print_error_i18n('no_help',$arg);
		}
	} else {
		print_out_i18n('help_header');
		print_list(get_builtin_commands());
	}
    return undef;
}

sub cmpl_help {
	my $text= shift;
	return (1,grep { Psh::Util::starts_with($_,$text) } get_builtin_commands());
}

$Psh::Builtins::help_builtin = '

=item * C<builtin COMMAND [ARGS]>

Run a shell builtin.

=cut ';

sub bi_builtin {
	my $text= shift;
	my ($command, $rest) = Psh::Parser::std_tokenize($text,2);
	if( $Psh::built_ins{$command} &&
		!_is_aliased($command) ) {
		return &{$Psh::built_ins{$command}}($rest);
	}
	{
		no strict 'refs';
		if( ref *{"Psh::Builtins::bi_$command"}{CODE} eq 'CODE') {
			my $coderef= *{"Psh::Builtins::bi_$command"};
			return &{$coderef}($rest);
		} elsif( ref *{"Psh::Builtins::Fallback::bi_$command"}{CODE} eq 'CODE') {
			my $coderef= *{"Psh::Builtins::Fallback::bi_$command"};
			return &{$coderef}($rest);
		}
	}
	print_error_i18n('no_such_builtin',$command,$Psh::bin);
	return 1;
}

sub cmpl_builtin {
	return cmpl_help(@_);
}

#####################################################################
# Utility functions
#####################################################################

# Returns a list of aliases commands
sub get_alias_commands {
	return keys %aliases;
}

# Returns a list of builtins
sub get_builtin_commands {
	no strict 'refs';
	my @list= ();
	my @sym = keys %{*{'Psh::Builtins::'}};
	for my $sym (sort @sym) {
		push @list, substr($sym,3) if substr($sym,0,3) eq 'bi_' &&
			ref *{'Psh::Builtins::'.$sym}{CODE} eq 'CODE';
	}
	return @list;
}


#####################################################################
# 'Fallback' builtins are following now
# Fallback builtins are NOT called under normal circumstances
# Instead they will be used if we expected a binary with that
# name to exist on the system but it did not
# (e.g. to simulate command.com/cmd.exe builtins on Win32
#  or simple stuff like ls on MacOS)
#####################################################################

package Psh::Builtins::Fallback;

#
# void env
#
# Prints out the current environment if no 'env' command is on
# the system
#

sub bi_env
{
	foreach my $key (keys %ENV) {
		print_out("$key=$ENV{$key}\n");
	}
	return undef;
}

# void bi_ls
# like the Unix binary but without options
sub bi_ls
{
	my $pattern= shift || '*';
	my $ps= $Psh::OS::FILE_SEPARATOR;
	$pattern.=$ps.'*' if( $pattern !~ /\*/ &&
						  -d Psh::Util::abs_path($pattern));
	my @files= map { 
		    return $1 if( m:\Q$ps\E([^\Q$ps\E]+)$:); $_
		} Psh::OS::glob($pattern);
	Psh::Util::print_list(@files);
	return undef;
}

package Psh::Builtins;

1;

__END__

=back

=head1 AUTHOR

the Psh team

=head1 SEE ALSO

L<psh>

=cut

# The following is for Emacs - I hope it won't annoy anyone
# but this could solve the problems with different tab widths etc
#
# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# c-basic-offset:4
# perl-indent-level:4
# perl-label-offset:0
# End:


