package Psh::OS::Unix;

use strict;
use vars qw($VERSION);
use POSIX qw(:sys_wait_h tcsetpgrp getpid setpgid);

use Psh::Util ':all';

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

$Psh::OS::PATH_SEPARATOR=':';
$Psh::OS::FILE_SEPARATOR='/';

#
# Returns the hostname of the machine psh is running on, preferrably
# the full version
#

sub get_hostname() {
	return qx(hostname);
}

#
# Returns a list of well-known hosts (from /etc/hosts)
#
sub get_known_hosts { 
	open(FILE,"< /etc/hosts") || return ();
	my $text='';
	while( <FILE>) { $text.=$_; }
	close(FILE);
	return Psh::Util::parse_hosts_file($text);
}

#
# Returns a list of all users on the system, prepended with ~
#
sub get_all_users {
	my @result= ();
	setpwent;
	while( my ($name)= getpwent) {
		push(@result,'~'.$name);
	}
	endpwent;
	return @result;
}

sub glob {
	my @result= glob(shift);
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
	if( $@) {
		print $text;
	}

	1 while unlink($tmp); #Possibly pointless VMSism
}

#
# Exit psh - you won't believe it, but exit needs special treatment on
# MacOS
#
sub exit() {
	CORE::exit( shift);
}

sub PATH_SEPARATOR { return ':'; }
sub FILE_SEPARATOR { return '/'; }

sub get_home_dir {
	return (getpwnam(shift))[7]
}

sub is_path_absolute {
	my $path= shift;

	return substr($path,0,1)='/';
}

sub get_path_extension { return (''); }

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
	# Why are the signal handlers changed for this method only ?!?

        # Current answer by gtw: I put these signal-handler changes in
        # here. It's the last bit of "magic" I copied from
        # bash-2.03/jobs.c . I don't know why it's necessary, I just
        # know that job control was erratic, sometimes causing hangs
        # when foreground children terminated, until I changed these
        # signal handlers. This whole function is closely modeled on
        # the function by the same name in bash-2.03/jobs.c .

	local $SIG{TSTP}  = 'IGNORE';
	local $SIG{TTIN}  = 'IGNORE';
	local $SIG{TTOU}  = 'IGNORE';
	local $SIG{CHLD}  = 'IGNORE';

	#
	# Perl will always complain about the tcsetpgrp if warnings
	# are enabled... so we switch it off here
	# TODO: Find out if really something is wrong with this line
	local $^W=0;
	tcsetpgrp(*STDIN,$_[0]);
}


#
# void _wait_for_system(int PID, [bool QUIET_EXIT])
#
# Waits for a program to be stopped/ended, prints no message on normal
# termination if QUIET_EXIT is specified and true.
#

sub _wait_for_system
{
	my($pid, $quiet) = @_;
        if (!defined($quiet)) { $quiet = 0; }

	my $psh_pgrp = getpgrp;

	my $pid_status = -1;

	my $job= $Psh::joblist->get_job($pid);

	while (1) {
		print_debug("[[About to give the terminal to $pid.]]\n");
		_give_terminal_to($pid);
		if (!$job->{running}) { $job->continue; }
		my $returnpid;
		{
			local $Psh::currently_active = $pid;
			$returnpid = waitpid($pid, &WUNTRACED);
			$pid_status = $?;
		}
		_give_terminal_to($psh_pgrp);
		print_debug("[[Just gave myself back the terminal. $pid $returnpid $pid_status]]\n");
		last if $returnpid<0;
		_handle_wait_status($returnpid, $pid_status, $quiet);
		last if $returnpid == $pid;
	}
}

#
# void _handle_wait_status(int PID, int STATUS, bool QUIET_EXIT)
#
# Take the appropriate action given that waiting on PID returned
# STATUS. Normal termination is not reported if QUIET_EXIT is true.
#

sub _handle_wait_status {
	my ($pid, $pid_status, $quiet) = @_;
	# Have to obtain these before we potentially delete the job
	my $job= $Psh::joblist->get_job($pid);
	my $command = $job->{call};
	my $visindex= $Psh::joblist->get_job_number($pid);
	my $verb='';
  
	if (&WIFEXITED($pid_status)) {
		$verb= "\u$Psh::text{done}" if (!$quiet);
		$Psh::joblist->delete_job($pid);
	} elsif (&WIFSIGNALED($pid_status)) {
		$verb = "\u$Psh::text{terminated} (" .
			Psh::signal_description(WTERMSIG($pid_status)) . ')';
		$Psh::joblist->delete_job($pid);
	} elsif (&WIFSTOPPED($pid_status)) {
		$verb = "\u$Psh::text{stopped} (" .
			Psh::signal_description(WSTOPSIG($pid_status)) . ')';
		$job->{running}= 0;
	}
	if ($verb) {
		print_out( "[$visindex] $verb $pid $command\n");
	}
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

#
# void fork_process( code|program, int fgflag)
#

sub fork_process {
	local( $Psh::code, $Psh::fgflag, $Psh::string) = @_;
	local $Psh::pid;

	unless ($Psh::pid = fork) { #child
		open(STDIN,"-");
		open(STDOUT,">-");
		open(STDERR,">&STDERR");
		remove_signal_handlers();
		setpgid(getpid(),getpid());
		Psh::OS::_give_terminal_to(getpid()) if $Psh::fgflag;
		if( ref($Psh::code) eq 'CODE') {
			&{$Psh::code};
		} else {
			{ exec $Psh::code; } # Avoid unreachable warning
			print_error_i18n(`exec_failed`,$Psh::code);
			&exit(-1); #use the subroutine in this module
		}
	}
	setpgid($Psh::pid,$Psh::pid);
	local $Psh::job= $Psh::joblist->create_job($Psh::pid,$Psh::string);
	if( !$Psh::fgflag) {
		my $visindex= $Psh::joblist->get_job_number($Psh::job->{pid});
		print_out("[$visindex] Background $Psh::pid $Psh::string\n");
	}
	_wait_for_system($Psh::pid, 1) if $Psh::fgflag;
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
			print_out("[$visindex] $verb $pid $command\n");

			if($fg_flag) {
				eval { _wait_for_system($pid, 0); };
			} elsif( !$qRunning) {
				$job->continue;
			}
		}
	}
}

###################################################################
# SIGNALS
###################################################################

#
# void remove_signal_handlers()
#
# TODO: Is there a way to do this in a loop over something from the
# Config module?
# Answer: no

sub remove_signal_handlers
{
	$SIG{INT}   = 'DEFAULT';
	$SIG{QUIT}  = 'DEFAULT';
	$SIG{CONT}  = 'DEFAULT';
	$SIG{STOP}  = 'DEFAULT';
	$SIG{TSTP}  = 'DEFAULT';
	$SIG{TTIN}  = 'DEFAULT';
	$SIG{TTOU}  = 'DEFAULT';
	$SIG{CHLD}  = 'DEFAULT';
}

#
# void setup_signal_handlers
#
sub setup_signal_handlers
{
	$SIG{'INT'}   = \&_signal_handler;
	$SIG{'QUIT'}  = \&_signal_handler;
	$SIG{'CONT'}  = \&_signal_handler;
	$SIG{'STOP'}  = \&_signal_handler;
	$SIG{'TSTP'}  = \&_signal_handler;
	$SIG{'TTIN'}  = \&_signal_handler;
	$SIG{'TTOU'}  = \&_signal_handler;
	$SIG{'CHLD'}  = \&_ignore_handler;
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
    die "SECRET $Psh::bin: Signal $sig\n"; # changed to SECRET... just in case
}

#
# void _signal_handler( string SIGNAL )
#

sub _signal_handler
{
	my ($sig) = @_;
	
	if ($Psh::currently_active > 0) {
		print_debug("Received signal SIG$sig, sending to $Psh::currently_active\n");

		kill $sig, $Psh::currently_active;
	} elsif ($Psh::currently_active < 0) {
		print_debug("Received signal SIG$sig, sending to Perl code\n");

		die "SECRET ${Psh::bin}: Signal $sig\n";
	} else {
		print_debug("Received signal SIG$sig, die-ing\n");
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
	my ($sig) = @_;
	$SIG{$sig} = \&_ignore_handler;
}


sub _error_handler
{
	my ($sig) = @_;
	print_error("Received SIG$sig - ignoring\n");
	$SIG{$sig} = \&_error_handler;
	kill 'INT',getpid(); # HACK to stop a possible endless loop!
}

#
# _resize_handler()
#

sub _resize_handler
{
	my ($sig) = @_;
	my ($cols, $rows) = (80, 24);

	eval {
		($cols,$rows)= &Term::Size::chars();
	};

	unless( $cols) {
		eval {
			($cols,$rows)= &Term::ReadKey::GetTerminalSize(*STDOUT);
		};
	}


# I do not really want to activate this before I know more about
# where this will work
#
#  	unless( $cols) {
#  		#
#  		# Portability alarm!! :-)
#  		#
#  		eval 'use "ioctl.ph';
#  		eval 'use "sys/ioctl.ph';
#  		eval 'use "sgtty.ph';
#		
#  		eval {
#  			my $TIOCGWINSZ = &TIOCGWINSZ if defined(&TIOCGWINSZ);
#  			my $TIOCGWINSZ = 0x40087468 if !defined($TIOCGWINSZ);
#  			my $winsz_t="S S S S";
#  			my $winsize= pack($winsz_t,0,0,0,0);
#  			if( ioctl(STDIN,$TIOCGWINSZ,$winsize)) {
#  				($rows,$cols)= unpack("S S S S",$winsize);
#  			}
#  		}
#  	}

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

	use Psh::OS;

=head1 DESCRIPTION

TBD

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
# perl-label-offset:0
# End:


