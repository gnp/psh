package Psh::Builtins;

use strict;
use vars qw($VERSION);

use Cwd;
use Cwd 'chdir';
use Psh::Util ':all';
use Psh::OS;

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

my $PS=Psh::OS::PATH_SEPARATOR();
my $FS=Psh::OS::FILE_SEPARATOR();

%Psh::array_exports=('PATH'=>$PS,'CLASSPATH'=>$PS,'LD_LIBRARY_PATH'=>$PS,
					 'FIGNORE'=>$PS,'CDPATH'=>$PS);

#
# string do_setenv(string command)
#
# command is of the form "VAR VALUE" or "VAR = VALUE" or "VAR"; sets
# $ENV{VAR} to "VALUE" in the first two cases, or to "$VAR" in the
# third case unless $VAR is undefined. Used by the setenv and export
# builtins. Returns VAR (which is a string with no $).

sub do_setenv
{
	my $arg = shift;
	if( $arg=~ /^\s*(\w+)(\s+|\s*=\s*)(.+)/ ) {
		my $var= $1;
		$var =~ s/^\$//;
		# Use eval so that variables may appear on RHS
		# (expression $3); use protected_eval so that lexicals
		# in this file don't shadow package variables
        	Psh::protected_eval("\$ENV{$var}=\"$3\"", 'do_setenv');
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

#
# void builtin_setenv(string command)
#
# Allows to set environment variables without needing to use
# $ENV{..}

sub setenv
{
	my $var = do_setenv(@_);
	if (!$var) {
		print_error("Usage: setenv <variable> <value>\n".
					"       setenv <variable>\n");
	}
	return undef;
}

#
# void builtin_export(string command)
#
# Like setenv, but also ties the variable so that changing it affects
# the environment
#

sub export
{
	my $var = do_setenv(@_);
	if ($var) {
		my @result = Psh::protected_eval("tied(\$$var)");
		my $oldtie = $result[0];
		if (defined($oldtie)) {
			if (ref($oldtie) ne 'Env') {
				print_warning("Variable \$$var is already ",
							  "tied via $oldtie, ",
							  "can't export.\n");
			}
		} else {
			Psh::protected_eval("use Env '$var';");
			if( exists($Psh::array_exports{$var})) {
				eval "use Env::Array";
				if( ! @$) {
					Psh::protected_eval("use Env::Array qw($var $Psh::array_exports{$var});");
				}
			}
		}
	} else {
		print_error("Usage: export <variable> [=] <value>\n".
					"       export <variable>\n");
	}
	return undef;
}

#
# int cd(string DIR)
#
# Changes directories to the given DIR; '-' is interpreted as the
# last directory that psh was in
#


{
	my $last_dir= '.'; # By default 'cd -' won't change directory at all.
	$ENV{OLDPWD}= $last_dir;

	sub cd
	{
		my $in_dir = shift;
		my $dirpath= $ENV{CDPATH} || '.';

		foreach my $cdbase (split $PS,$dirpath) {
			my $dir= $in_dir;
			$dir = $last_dir if $dir eq '-';
			if( $cdbase eq '.' ||
				substr($dir,0,1) eq $FS) {
				$dir = Psh::Util::abs_path($dir);
			} else {
				$dir = Psh::Util::abs_path($cdbase.$FS.$dir);
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
}


#
# int kill(string COMMAND)
#

sub kill
{
	if( ! Psh::OS::has_job_control()) {
		print_error_i18n('no_jobcontrol');
		return undef;
	}

	my @args = split(' ',$_[0]);
	my ($sig, $pid, $job);

	if (scalar(@args) == 1) {
		$pid = $args[0];
		$sig = 'TERM';
	} elsif (scalar(@args) == 2) {
		($sig, $pid) = @args;
	} else {
		print_error("kill: usage: kill <sig> <pid>\n");
		return 1;
	}

	if ($pid =~ m|^%(\d+)$|) {
		my $temp = $1 - 1;

		$job= $Psh::joblist->find_job($temp);
		if( !defined($job)) {
			print_error("kill: No such job $pid\n");
			return 1;
		}

		$pid = $job->{pid};
	}

	if ($pid =~ m/\D/) {
		print_error("kill: Unknown job specification $pid\n");
		return 1;
	}

	if ($sig ne 'CONT' and $Psh::joblist->job_exists($pid)
		and !(($job=$Psh::joblist->get_job($pid))->{running})) {
		#Better wake up the process so it can respond to this signal
		$job->continue;
	}

	if (CORE::kill($sig, $pid) != 1) {
		print_error("kill: Error sending signal $sig to process $pid\n");
		return 1;
	}

	if ($sig eq 'CONT' and $Psh::joblist->job_exists($pid)) {
		$Psh::joblist->get_job($pid)->{running}=1;
	}

	return 0;
}


#
# int which(string COMMAND)
#

sub which
{
	my $cmd   = shift;

	print_debug("[which $cmd]\n");

	if (!defined($cmd) or $cmd eq '') {
		print_error("which: requires a command or command line as argument\n");
		return 1;
	}
  
	my @words = Psh::Parser::decompose(' ',$cmd,undef,1,undef,'\&');

	for my $strat (@Psh::strategies) {
		if (!defined($Psh::strategy_which{$strat})) {
			print_warning("${Psh::bin}: WARNING: unknown strategy '$strat'.\n");
			next;
		}

		my $how = &{$Psh::strategy_which{$strat}}(\$cmd,\@words);

		if ($how) {
			print_out("$cmd evaluates under strategy $strat by: $how\n");
			return 0;
		}
	}

	print_warning("which: can't determine how to evaluate $cmd\n");

	return 1;
}


#
# int alias(string COMMAND)
#

# Cannot use "static" variables anymore as I do not know how to
# lookup the function otherwise
my %aliases = ();
	
sub alias
{
	my $line = shift;
	my ($command, $firstDelim, @rest) = Psh::Parser::decompose('([ \t\n=]+)', $line, undef, 0);
	if (!defined(@rest)) { @rest = (); }
	my $text = join('',@rest); # reconstruct everything after the
	# first delimiter, sans quotes
	if (($command eq "") && ($text eq "")) {
		my $wereThereSome = 0;
		for $command (sort keys %aliases) {
			print_out("alias $command='$aliases{$command}'\n");
			$wereThereSome = 1;
		}
		if (!$wereThereSome) {
			print_out("No aliases.\n");
		}
	} elsif( $text eq '') {
		print_out("alias $command='$aliases{$command}'\n");
	} else {
		print_debug("[[ Aliasing '$command' to '$text']]\n");
		# my apologies for the gobbledygook
		my $string_to_eval = "\$Psh::built_ins{$command} = "
			. " sub { local \$Psh::built_ins{$command} = undef; Psh::evl(q($text) .' '. shift); }";
		print_debug("[[ alias evaluating: $string_to_eval ]]\n");
		eval($string_to_eval);
		if ($@) { print_error($@); return 1; }
		# if successful, record the alias
		$aliases{$command} = $text;
	}
	return 0;
}

sub unalias {
	my $name= shift;
	if( $name eq '-a' || $name eq 'all' ) {
		%aliases= ();
		$Psh::built_ins= ();
	} elsif( exists($aliases{$name})) {
		delete($aliases{$name});
		delete($Psh::built_ins{$name});
	} else {
		print_error_i18n('unalias_noalias', $name);
		return 1;
	}
	return 0;
}

#
# void fg(int JOB_NUMBER)
#

sub fg
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


#
# int bg(string JOB | command)
#

sub bg
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


#
# void jobs()
#
# Checking whether jobs are running might print reports that
# jobs have stopped, so accumulate the job list and print it
# all at once so it's readable.
#

sub jobs {
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
		else                 { $result .= " (stopped)\n"; }
		$visindex++;
	}

	if (!$result) { $result = "No jobs.\n"; }

	print_out($result);

	return undef;
}


#
# void exit(int RETURN_CODE)
#
# TODO: What if a string is passed in?
#

sub exit
{
	my $result = shift;
	$result = 0 unless defined($result) && $result;

	if ($Psh::save_history && $Psh::readline_saves_history) {
		$Psh::term->WriteHistory($Psh::history_file);
	}
	
	my $file= "$ENV{HOME}/.${Psh::bin}_logout";
	if( -r $file) {
		process_file(abs_path($file));
	}

	Psh::OS::exit($result);
}


#
# void source(string LIST_OF_FILES)
#

sub source
{
	local $Psh::echo = 0;

	for my $file (split(' ',$_[0])) { Psh::process_file(abs_path($file)); }

	return undef;
}


#
# void readline(string IGNORED)
#
# Interface to the readline module being used. Currently very rudimentary 
#
# TODO: How can we print out the current bindings in an
# ReadLine-implementation-independent way? We should allow rebinding
# of keys if Readline interface allows it, etc.
#

sub readline
{
	print_out_i18n('builtin_readline_header',$Psh::term->ReadLine());

	my $featureref = $Psh::term->Features();

	for my $feechr (keys %{$featureref}) {
		print_out("  $feechr => ${$featureref}{$feechr}\n");
	}

	return undef;
}

#
# void env
#
# Prints out the current environment if no 'env' command is on
# the system
#

sub env
{
	my $original_env=Psh::Util::which('env');
	if( $original_env) {
		Psh::evl($original_env.' '.shift);
	} else {
		foreach my $key (keys %ENV) {
			print_out("$key=$ENV{$key}\n");
		}
	}
	return undef;
}

1;

__END__

=head1 NAME

Psh::Builtins - Package containing Psh builtins and possibly loading them
on the fly

=head1 SYNOPSIS

  use Psh::Builtins (:all);

=head1 DESCRIPTION

Psh::Builtins currently contains Perl Shell's hardcoded builtins,
but may later on be extended to load them on the fly from seperate
modules.

=head1 AUTHOR

blaaa

=head1 SEE ALSO

=cut

# The following is for Emacs - I hope it won't annoy anyone
# but this could solve the problems with different tab widths etc
#
# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# c-basic-offset:4
# perl-indent-level:4
# End:


