package Psh::OS::Unix;

use strict;
use vars qw($VERSION);
use POSIX qw(:sys_wait_h tcsetpgrp setpgid);
use Config;
use File::Spec;
use Sys::Hostname;
use FileHandle;
use User::pwent;

use Psh::Util ':all';

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

$Psh::OS::PATH_SEPARATOR=':';
$Psh::OS::FILE_SEPARATOR='/';

$Psh::rc_file = ".pshrc";
$Psh::history_file = ".psh_history";

#
# Returns the hostname of the machine psh is running on, preferrably
# the full version
#

sub get_hostname() {
	return hostname;
}

#
# Returns a list of well-known hosts (from /etc/hosts)
#
sub get_known_hosts {
	my $hosts_file = "/etc/hosts"; # TODO: shouldn't be hard-coded?
	my $hfh = new FileHandle($hosts_file, 'r');
	return ("localhost") unless defined($hfh);
	my $hosts_text = join('', <$hfh>);
	$hfh->close();
	return Psh::Util::parse_hosts_file($hosts_text);
}

#
# Returns a list of all users on the system, prepended with ~
#
sub get_all_users {
	my @result= ();
	CORE::setpwent;
	while (my ($name) = CORE::getpwent) {
		push(@result,'~'.$name);
	}
	CORE::endpwent;
	return @result;
}

#
# void display_pod(text)
#
sub display_pod {
	my $tmp= POSIX::tmpnam;
	my $text= shift;

	open( TMP,">$tmp");
	print TMP $text;
	close(TMP);

	eval {
		use Pod::Text;
		Pod::Text::pod2text($tmp,*STDOUT);
	};
	print $text if $@;

	unlink($tmp);
}

#
# Exit psh - you won't believe it, but exit needs special treatment on
# MacOS
#
sub exit() {
        CORE::exit($_[0]) if $_[0];
        CORE::exit(0);
}

sub get_home_dir {
	my $user = shift || $ENV{USER};
	return $ENV{HOME} if ((! $user) && (-d $ENV{HOME}));
	return getpwnam($user)->dir;
}

sub get_rc_files {
	my @rc=();

	if (-r '/etc/pshrc') {
		push @rc, '/etc/pshrc';
	}
	my $home= Psh::OS::get_home_dir();
	if ($home) { push @rc, File::Spec->catfile($home,'.pshrc') };
	return @rc;
}

sub get_path_extension { return (''); }

#
# int inc_shlvl ()
#
# Increments $ENV{SHLVL}. Also checks for login shell status and does
# appropriate OS-specific tasks depending on it.
#
sub inc_shlvl {
	my $ruid_pwent = getpwuid($<);
	if ((! $ENV{SHLVL}) && ($ruid_pwent->shell eq $0)) { # would use $Psh::bin, but login shells are guaranteed full paths
		$Psh::login_shell = 1;
		$ENV{SHLVL} = 1;
	} else {
		$Psh::login_shell = 0;
		$ENV{SHLVL}++;
	}
}


###################################################################
# JOB CONTROL
###################################################################


#
# void _give_terminal_to (int PID)
#
# Make pid the foreground process of the terminal controlling STDIN.
#

sub _give_terminal_to
{
	# If a fork of a psh fork tries to call this then exit
	# as it would probably mess up the shell
	# This hack is necessary as e.g.
	# alias ls=/bin/ls
	# ls &
	# call fork_process from within a fork

	return if $Psh::OS::Unix::forked_already;

	local $SIG{TSTP}  = 'IGNORE';
	local $SIG{TTIN}  = 'IGNORE';
	local $SIG{TTOU}  = 'IGNORE';
	local $SIG{CHLD}  = 'IGNORE';

	tcsetpgrp(fileno STDIN,$_[0]);
}


#
# void _wait_for_system(int PID, [bool QUIET_EXIT], [bool NO_TERMINAL])
#
# Waits for a program to be stopped/ended, prints no message on normal
# termination if QUIET_EXIT is specified and true.
#
# If NO_TERMINAL is specified and true it won't try to transfer
# terminal ownership
#

sub _wait_for_system
{
	my($pid, $quiet) = @_;
	if (!defined($quiet)) { $quiet = 0; }

	my $psh_pgrp = getpgrp;

	my $pid_status = -1;

	my $job= $Psh::joblist->get_job($pid);

	return if ! $job;

	my $term_pid= $job->{pgrp_leader}||$pid;

	_give_terminal_to($term_pid);

	my $output='';

	while (1) {
		if (!$job->{running}) { $job->continue; }
		my $returnpid;
		{
			local $Psh::currently_active = $pid;
			$returnpid = waitpid($pid,&WUNTRACED);
			$pid_status = $?;
		}
		last if $returnpid<1;
		# Collect output here - we cannot print it while another
		# process might possibly be in the foreground;
		$output.=_handle_wait_status($returnpid, $pid_status, $quiet, 1);
		last if $returnpid == $pid;
	}
	_give_terminal_to($psh_pgrp);
	Psh::Util::print_out($output) if length($output);
}

#
# void _handle_wait_status(int PID, int STATUS, bool QUIET_EXIT)
#
# Take the appropriate action given that waiting on PID returned
# STATUS. Normal termination is not reported if QUIET_EXIT is true.
#

sub _handle_wait_status {
	my ($pid, $pid_status, $quiet, $collect) = @_;
	# Have to obtain these before we potentially delete the job
	my $job= $Psh::joblist->get_job($pid);
	my $command = $job->{call};
	my $visindex= $Psh::joblist->get_job_number($pid);
	my $verb='';

	if (&WIFEXITED($pid_status)) {
		my $status=&WEXITSTATUS($pid_status);
		if ($status==0) {
			$verb= "\u$Psh::text{done}" if (!$quiet);
		} else {
			$verb= "\u$Psh::text{error}";
		}
		$Psh::joblist->delete_job($pid);
	} elsif (&WIFSIGNALED($pid_status)) {
		$verb = "\u$Psh::text{terminated} (" .
			Psh::OS::signal_description(WTERMSIG($pid_status)) . ')';
		$Psh::joblist->delete_job($pid);
	} elsif (&WIFSTOPPED($pid_status)) {
		$verb = "\u$Psh::text{stopped} (" .
			Psh::OS::signal_description(WSTOPSIG($pid_status)) . ')';
		$job->{running}= 0;
	}
	if ($verb && $visindex>0) {
		my $line="[$visindex] $verb $pid $command\n";
		return $line if $collect;

		Psh::Util::print_out($line );
	}
	return '';
}


#
# void reap_children()
#
# Checks wether any children we spawned died
#

sub reap_children
{
	my $returnpid=0;
	while (($returnpid = waitpid(-1, &WNOHANG | &WUNTRACED)) > 0) {
		_handle_wait_status($returnpid, $?);
	}
}

sub execute_complex_command {
	my @array= @{shift()};
	my $fgflag= shift @array;
	my @return_val;
	my $eval_thingie;
	my $pgrp_leader= 0;
	my $pid;
	my $string='';
	my @tmp;

	for( my $i=0; $i<@array; $i++) {
		my ($coderef, $how, $options, $words, $strat, $text)= @{$array[$i]};
		$text||='';

		my $line= join(' ',@$words);
		my $forcefork;
		($eval_thingie,$words,$forcefork, @return_val)= &$coderef( \$line, $words,$how,$i>0);

		if( defined($eval_thingie)) {
			if( $#array) {
				pipe READ,WRITE;
			}
			if( $i>0) {
				unshift(@$options,['REDIRECT','<&',0,'INPUT']);
			}
			if( $i<$#array) {
				unshift(@$options,['REDIRECT','>&',1,'WRITE']);
			}
			my $termflag=!($i==$#array);

			($pid,@tmp)= _fork_process($eval_thingie,$words,
									   $fgflag,$text,$options,
									   $pgrp_leader,$termflag,
									   $forcefork);

			if( !$i && !$pgrp_leader) {
				$pgrp_leader=$pid;
			}

			if( $i<$#array && $#array) {
				close(WRITE);
				open(INPUT,"<&READ");
			}
			if( @return_val < 1 ||
				!defined($return_val[0])) {
				@return_val= @tmp;
			}
		}
		$string.='|' if $i>0;
		$string.=$text;
	}

	if( $pid) {
		my $job= $Psh::joblist->create_job($pid,$string);
		$job->{pgrp_leader}=$pgrp_leader;
		if( $fgflag) {
			_wait_for_system($pid, 1);
		} else {
			my $visindex= $Psh::joblist->get_job_number($job->{pid});
			Psh::Util::print_out("[$visindex] Background $pgrp_leader $string\n");
		}
	}
	return @return_val;
}

sub _setup_redirects {
	my $options= shift;

	return [] if ref $options ne 'ARRAY';

	my @cache=();
	foreach my $option (@$options) {
		if( $option->[0] eq 'REDIRECT') {
			my $file= $option->[1].$option->[3];
			my $type= $option->[2];

			if( $type==0) {
				open(OLDIN,"<&STDIN");
				open(STDIN,$file);
				select(STDIN);
				$|=1;
				if( $file eq '<&INPUT') {
					close(INPUT);
					# Just to get rid of the warning
				}
			} elsif( $type==1) {
				open(OLDOUT,">&STDOUT");
				open(STDOUT,$file);
				select(STDOUT);
				$|=1;
			} elsif( $type==2) {
				open(OLDERR,">&STDERR");
				open(STDERR,$file);
				select(STDERR);
				$|=1;
			}
			push @cache, $type;
		}
	}
	select(STDOUT);
	return \@cache;
}

sub _remove_redirects {
	my $cache= shift;

	foreach my $type (@$cache) {
		if( $type==0) {
			close(STDIN);
			open(STDIN,"<&OLDIN");
			close(OLDIN);
		} elsif( $type==1) {
			close(STDOUT);
			open(STDOUT,">&OLDOUT");
			close(OLDOUT);
		} elsif( $type==2) {
			close(STDERR);
			open(STDERR,">&OLDERR");
			close(OLDERR);
		}
	}
}

#
# void fork_process( code|program, words,
#                    int fgflag, text to display in jobs,
#                    redirection options,
#                    pid of pgroupleader, do not set terminal flag,
#                    force a fork?)
#

sub _fork_process {
    my( $code, $words, $fgflag, $string, $options,
		$pgrp_leader, $termflag, $forcefork) = @_;
	my($pid);

	# HACK - if it's foreground code AND perl code
	# we do not fork, otherwise we'll never get
	# the result value, changed variables etc.
	if( $fgflag && !$forcefork && ref($code) eq 'CODE') {
		my $cache= _setup_redirects($options);
		my @result= eval { &$code };
		_remove_redirects($cache);
		Psh::Util::print_error($@) if $@;
		return (0,@result);
	}

	unless ($pid = fork) { #child
		unless (defined $pid) {
			Psh::Util::print_error_i18n('fork_failed');
			return (-1,undef);
		}

		$Psh::OS::Unix::forked_already=1;
		close(READ) if( $pgrp_leader);
		_setup_redirects($options);
		setpgid(0,$pgrp_leader||$$);
		_give_terminal_to($pgrp_leader||$$) if $fgflag && !$termflag;
		remove_signal_handlers();

		if( ref($code) eq 'CODE') {
			&{$code};
			&exit(0);
		} else {
			{
				if( ! ref $options) {
					exec $code;
				} else {
					$code= shift @$words;
					exec { $code } @$words;
				}
			} # Avoid unreachable warning
			Psh::Util::print_error_i18n(`exec_failed`,$code);
			&exit(-1);
		}
	}
	setpgid($pid,$pgrp_leader||$pid);
	_give_terminal_to($pgrp_leader||$pid) if $fgflag && !$termflag;
	return ($pid,undef);
}

sub fork_process {
    my( $code, $fgflag, $string, $options) = @_;
	my ($pid,@result)= _fork_process($code,undef,$fgflag,$string,$options);
	return @result if !$pid;
	my $job= $Psh::joblist->create_job($pid,$string);
	if( !$fgflag) {
		my $visindex= $Psh::joblist->get_job_number($job->{pid});
		Psh::Util::print_out("[$visindex] Background $pid $string\n");
	}
	_wait_for_system($pid, 1) if $fgflag;
	return undef;
}

#
# Returns true if the system has job_control abilities
#
sub has_job_control { return 1; }

#
# void restart_job(bool FOREGROUND, int JOB_INDEX)
#
sub restart_job
{
	my ($fg_flag, $job_to_start) = @_;

	my $job= $Psh::joblist->find_job($job_to_start);

	if(defined($job)) {
		my $pid = $job->{pid};
		my $command = $job->{call};

		if ($command) {
			my $verb = "\u$Psh::text{restart}";
			my $qRunning = $job->{running};
			if ($fg_flag) {
			  $verb = "\u$Psh::text{foreground}";
			} elsif ($qRunning) {
			  # bg request, and it's already running:
			  return;
			}
			my $visindex = $Psh::joblist->get_job_number($pid);
			Psh::Util::print_out("[$visindex] $verb $pid $command\n");

			if($fg_flag) {
				eval { _wait_for_system($pid, 0); };
			} elsif( !$qRunning) {
				$job->continue;
			}
		}
	}
}

# Simply doing backtick eval - mainly for Prompt evaluation
sub backtick {
	return `@_`;
}

###################################################################
# SIGNALS
###################################################################

# Setup special treatment of certain signals
# Having a value of 0 means to ignore the signal completely in
# the loops while a code ref installs a different default
# handler
my %special_handlers= (
					   'CHLD' => \&_ignore_handler,
					   'CLD'  => \&_ignore_handler,
					   'TTOU' => \&_ttou_handler,
					   'TTIN' => \&_ttou_handler,
					   'TERM' => \&exit,
					   'HUP'  => \&exit,
					   'SEGV' => 0,
					   'WINCH'=> 0,
					   'ZERO' => 0,
					   );

# Fetching the signal names from Config instead of from %SIG
# has the advantage of avoiding Perl internal signals

my @signals= split(' ', $Config{sig_name});


#
# void remove_signal_handlers()
#
# This used to manually set INT, QUIT, CONT, STOP, TSTP, TTIN,
# TTOU, and CHLD.
#
# The new technique changes the settings of *all* signals. It is
# from Recipe 16.13 of The Perl Cookbook (Page 582). It should be
# compatible with Perl 5.004 and later.
#

sub remove_signal_handlers
{
	foreach my $sig (@signals) {
		next if exists($special_handlers{$sig}) &&
			! ref($special_handlers{$sig});
		$SIG{$sig} = 'DEFAULT';
	}
}

#
# void setup_signal_handlers
#
# This used to manually set INT, QUIT, CONT, STOP, TSTP, TTIN,
# TTOU, and CHLD.
#
# See comment for remove_signal_handlers() for more information.
#

sub setup_signal_handlers
{
	foreach my $sig (@signals) {
		if( exists($special_handlers{$sig})) {
			if( ref($special_handlers{$sig})) {
				$SIG{$sig}= $special_handlers{$sig};
			}
			next;
		}
		$SIG{$sig} = \&_signal_handler;
	}

	reinstall_resize_handler();
}


#
# Setup the SIGSEGV handler
#
sub setup_sigsegv_handler
{
	$SIG{SEGV} = \&_error_handler;
}

#
# Setup SIGINT handler for readline
#
sub setup_readline_handler
{
	$SIG{INT}= \&_readline_handler;
}

sub remove_readline_handler
{
	$SIG{INT}= \&_signal_handler;
}

sub reinstall_resize_handler
{
	&_resize_handler('WINCH');
}


#
# readline_handler()
#
# Readline ^C handler.
#

sub _readline_handler
{
	my $sig= shift;
	setup_readline_handler();
	print "\n"; # Clean up the display
	die "SECRET $Psh::bin: Signal $sig\n"; # changed to SECRET... just in case
}

sub _ttou_handler
{
	_give_terminal_to($$);
}

#
# void _signal_handler( string SIGNAL )
#

sub _signal_handler
{
	my ($sig) = @_;

	if ($Psh::currently_active > 0) {
		Psh::Util::print_debug("Received signal SIG$sig, sending to $Psh::currently_active\n");

		kill $sig, -$Psh::currently_active;
	} elsif ($Psh::currently_active < 0) {
		Psh::Util::print_debug("Received signal SIG$sig, sending to Perl code\n");
		die "SECRET ${Psh::bin}: Signal $sig\n";
	} else {
		_give_terminal_to($$);
		Psh::Util::print_debug("Received signal SIG$sig, die-ing\n");
		die "SECRET ${Psh::bin}: Signal $sig\n" if $sig eq 'INT';
	}

	$SIG{$sig} = \&_signal_handler;
}


#
# ignore_handler()
#
# From Markus: Apparently letting a signal execute an empty sub is not the same
# as setting the sighandler to IGNORE
#

sub _ignore_handler
{
}


sub _error_handler
{
	my ($sig) = @_;
	Psh::Util::print_error_i18n('unix_received_strange_sig',$sig);
	kill 'INT', $$; # HACK to stop a possible endless loop!
}

#
# _resize_handler()
#

sub _resize_handler
{
	my ($sig) = @_;
	my ($cols, $rows); # Assume nothing so that unless works!

	eval {
		($cols,$rows)= &Term::Size::chars();
	};

	unless( $cols) {
		eval {
			($cols,$rows)= &Term::ReadKey::GetTerminalSize(*STDOUT);
		};
	}

	if(($cols > 0) && ($rows > 0)) {
		$ENV{COLUMNS} = $cols;
		$ENV{LINES}   = $rows;
		if( $Psh::term) {
			$Psh::term->Attribs->{screen_width}=$cols-1;
		}
		# for ReadLine::Perl
	}

	$SIG{$sig} = \&_resize_handler;
}



1;

__END__

=head1 NAME

Psh::OS::Unix - contains Unix specific code


=head1 SYNOPSIS

	use Psh::OS::Unix;

=head1 DESCRIPTION

Implements the Unix specific parts of Psh::OS

=head1 AUTHOR

various

=cut

# The following is for Emacs - I hope it won't annoy anyone
# but this could solve the problems with different tab widths etc
#
### The One True Width of tabs is 8 characters.  The point about tabs over
### spaces is that it doesn't matter *WHAT* value you give it.
### Unfortunately people persist in using the space bar.
### Greater than three spaces should be a macro for TAB in all editors.
#
# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# c-basic-offset:4
# perl-indent-level:4
# perl-label-offset:0
# End:


