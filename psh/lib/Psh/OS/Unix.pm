package Psh::OS::Unix;

use strict;
require POSIX;
require Psh::Locale;

$Psh::OS::PATH_SEPARATOR=':';
$Psh::OS::FILE_SEPARATOR='/';

$Psh::history_file = ".psh_history";

# Sets the title of the current window
sub set_window_title {
	my $title= shift;
	my $term= $ENV{TERM};
	if( $term=~ /^(rxvt.*)|(xterm.*)|(.*xterm)|(kterm)|(aixterm)|(dtterm)/) {
		print "\017\033]2;$title\007";
	}
}

#
# Returns the hostname of the machine psh is running on, preferrably
# the full version
#

sub get_hostname {
	require Sys::Hostname;
	return Sys::Hostname::hostname();
}

sub getcwd_psh {
    my $cwd;
    chomp($cwd = `pwd`);
    $cwd;
}

#
# Returns a list of well-known hosts (from /etc/hosts)
#
sub get_known_hosts {
	my $hosts_file = "/etc/hosts"; # TODO: shouldn't be hard-coded?
	my @result=();
	local *F_KNOWNHOST;
	if (open(F_KNOWNHOST,"< $hosts_file")) {
		my $hosts_text = join ('', <F_KNOWNHOST>);
		close(F_KNOWNHOST);
		push @result,Psh::Util::parse_hosts_file($hosts_text);
	}
	my $tmp= catfile(Psh::OS::get_home_dir(),
					 '.ssh','known_hosts');
	if (-r $tmp) {
		if (open(F_KNOWNHOST, "< $tmp")) {
			while (<F_KNOWNHOST>) {
				chomp;
				next unless $_;
				if (/^([a-zA-Z].*?)\,/) {
					push @result, $1;
				}
			}
		}
	}
	if (!@result) {
		push @result,'localhost';
	}
	return @result;
}

#
# Returns a list of all users on the system, prepended with ~
#
{
	my @user_cache;
	sub get_all_users {
		unless (@user_cache) {
			CORE::setpwent;
			while (my ($name) = CORE::getpwent) {
				push(@user_cache,'~'.$name);
			}
			CORE::endpwent;
		}
		return @user_cache;
	}
}

#
# void display_pod(text)
#
sub display_pod {
	my $tmp= Psh::OS::tmpnam();
	my $text= shift;

	local *TMP;
	open( TMP,">$tmp");
	print TMP $text;
	close(TMP);

	eval {
		require Pod::Text;
		Pod::Text::pod2text($tmp,*STDOUT);
	};
	Psh::Util::print_debug_class('e',"Error: $@") if $@;
	print $text if $@;

	unlink($tmp);
}

sub get_home_dir {
	my $user = shift || $ENV{USER};
	return $ENV{HOME} if ((! $user) && (-d $ENV{HOME}));
	return (CORE::getpwnam($user))[7]||'';
}

sub get_rc_files {
	my @rc=();

	if (-r '/etc/pshrc') {
		push @rc, '/etc/pshrc';
	}
	my $home= Psh::OS::get_home_dir();
	if ($home) { push @rc, catfile($home,'.pshrc') };
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
	my @pwent = CORE::getpwuid($<);
	if ((! $ENV{SHLVL}) && ($pwent[8] eq $0)) { # would use $Psh::bin, but login shells are guaranteed full paths
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

{
	my $terminal_owner=0;

	sub _give_terminal_to
    {
		# If a fork of a psh fork tries to call this then exit
		# as it would probably mess up the shell
		# This hack is necessary as e.g.
		# alias ls=/bin/ls
		# ls &
		# call fork_process from within a fork

		return if $Psh::OS::Unix::forked_already;
		return if $terminal_owner==$_[0];
		$terminal_owner=$_[0];

		local $SIG{TSTP}  = 'IGNORE';
		local $SIG{TTIN}  = 'IGNORE';
		local $SIG{TTOU}  = 'IGNORE';
		local $SIG{CHLD}  = 'IGNORE';

		my ($pkg,$file,$line,$sub)= caller(1);
		my $status= POSIX::tcsetpgrp(fileno STDIN,$_[0]);
	}

	sub _get_terminal_owner
    {
		return $terminal_owner;
	}
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

	my $psh_pgrp = CORE::getpgrp();

	my $pid_status = -1;

	my $job= Psh::Joblist::get_job($pid);

	return if ! $job;

	my $term_pid= $job->{pgrp_leader}||$pid;

	_give_terminal_to($term_pid);

	my $output='';
	my $status=1;
	my $returnpid;
	while (1) {
		if (!$job->{running}) { $job->continue; }
		{
			local $Psh::currently_active = $pid;
			$returnpid = CORE::waitpid($pid,POSIX::WUNTRACED());
			$pid_status = $?;
		}
		last if $returnpid<1;

		# Very ugly work around for the problem that
		# processes occasionally get SIGTTOUed without reason
		# We can do this here because we know the process has
		# to run and could not have been stopped by TTOU
		if ($returnpid== $pid &&
			POSIX::WIFSTOPPED($pid_status) &&
			Psh::OS::signal_name(POSIX::WSTOPSIG($pid_status)) eq 'TTOU') {
			$job->continue;
			next;
		}
		# Collect output here - we cannot print it while another
		# process might possibly be in the foreground;
		$output.=_handle_wait_status($returnpid, $pid_status, $quiet, 1);
		if ($returnpid == $pid) {
			$status=POSIX::WEXITSTATUS($pid_status);
			last;
		}
	}
	_give_terminal_to($psh_pgrp);
	Psh::Util::print_out($output) if length($output);
	return $status==0;
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
	my $job= Psh::Joblist::get_job($pid);
	my $command = $job->{call};
	my $visindex= Psh::Joblist::get_job_number($pid);
	my $verb='';

	if (POSIX::WIFEXITED($pid_status)) {
		my $status= POSIX::WEXITSTATUS($pid_status);
		if ($status==0) {
			$verb= ucfirst(Psh::Locale::get_text('done')) unless $quiet;
		} else {
			$verb= ucfirst(Psh::Locale::get_text('error'));
		}
		Psh::Joblist::delete_job($pid);
	} elsif (POSIX::WIFSIGNALED($pid_status)) {
		my $tmp= Psh::Locale::get_text('terminated');
		$verb = "\u$tmp (" .
			Psh::OS::signal_description(POSIX::WTERMSIG($pid_status)) . ')';
		Psh::Joblist::delete_job($pid);
	} elsif (POSIX::WIFSTOPPED($pid_status)) {
		my $tmp= Psh::Locale::get_text('stopped');
		$verb = "\u$tmp (" .
			Psh::OS::signal_description(POSIX::WSTOPSIG($pid_status)) . ')';
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
	while (($returnpid = CORE::waitpid(-1, POSIX::WNOHANG() |
									   POSIX::WUNTRACED())) > 0) {
		_handle_wait_status($returnpid, $?);
	}
}

sub execute_complex_command {
	my @array= @{shift()};
	my $fgflag= shift @array;
	my @return_val;
	my $success= 0;
	my $eval_thingie;
	my $pgrp_leader= 0;
	my $pid;
	my $string='';
	my @tmp;

	my ($read,$write,$input);
	for( my $i=0; $i<@array; $i++) {
		# ([ $strat, $how, \@options, \@words, $line]);
		my ($strategy, $how, $options, $words, $text, $opt)= @{$array[$i]};
		local $Psh::current_options= $opt;
		$text||='';

		my $line= join(' ',@$words);
		my $forcefork;
		($success, $eval_thingie,$words,$forcefork, @return_val)= $strategy->execute( \$line, $words, $how, $i>0);

		$forcefork||=$i<$#array;

		if( defined($eval_thingie)) {
			if( $#array) {
				($read,$write)= POSIX::pipe();
			}
			if( $i>0) {
				unshift(@$options,[Psh::Parser::T_REDIRECT(),'<&',0,$input]);
			}
			if( $i<$#array) {
				unshift(@$options,[Psh::Parser::T_REDIRECT(),'>&',1,$write]);
			}
			my $termflag=!($i==$#array);

			($pid,$success,@tmp)= _fork_process($eval_thingie,$words,
												$fgflag,$text,$options,
												$pgrp_leader,$termflag,
												$forcefork);

			if( !$i && !$pgrp_leader) {
				$pgrp_leader=$pid;
			}

			if( $i<$#array && $#array) {
				POSIX::close($write);
				$input= $read;
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
		my $job= Psh::Joblist::create_job($pid,$string);
		$job->{pgrp_leader}=$pgrp_leader;
		if( $fgflag) {
			$success=_wait_for_system($pid, 1);
		} else {
			my $visindex= Psh::Joblist::get_job_number($job->{pid});
			Psh::Util::print_out("[$visindex] Background $pgrp_leader $string\n");
		}
	}
	return ($success,\@return_val);
}

sub _setup_redirects {
	my $options= shift;
	my $save= shift;

	return [] if ref $options ne 'ARRAY';

	my @cache=();
	foreach my $option (@$options) {
		if( $option->[0] == Psh::Parser::T_REDIRECT()) {
			my $type= $option->[2];
			my $cachefileno;

			if ($option->[1] eq '<&') {
				POSIX::dup2($option->[3], $type);
			} elsif ($option->[1] eq '>&') {
				POSIX::dup2($option->[3], $type);
			} elsif ($option->[1] eq '<') {
				my $tmpfd= POSIX::open( $option->[3], &POSIX::O_RDONLY);
				POSIX::dup2($tmpfd, $type);
				POSIX::close($tmpfd);
			} elsif ($option->[1] eq '>') {
				my $tmpfd= POSIX::open( $option->[3], &POSIX::O_WRONLY |
										&POSIX::O_TRUNC | &POSIX::O_CREAT );
				POSIX::dup2($tmpfd, $type);
				POSIX::close($tmpfd);
			} elsif ($option->[1] eq '>>') {
				my $tmpfd= POSIX::open( $option->[3], &POSIX::O_WRONLY |
									   &POSIX::O_CREAT);
				POSIX::dup2($tmpfd, $type);
				POSIX::close($tmpfd);
			}
			if ($^F<$type) { # preserve filedescriptors higher than 2
				$^F=$type;
			}
		}
	}
	select(STDOUT);
	return \@cache;
}

sub _has_redirects {
	my $options= shift;
	return 0 if ref $options ne 'ARRAY';

	foreach my $option (@$options) {
		return 1 if( $option->[0] == Psh::Parser::T_REDIRECT());
	}
	return 0;
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

	# HACK - if it's foreground code AND perl code AND
	# there are no redirects
	# we do not fork, otherwise we'll never get
	# the result value, changed variables etc.
	if( $fgflag and !$forcefork and ref($code) eq 'CODE'
		and !_has_redirects($options)
	  ) {
		my @result= eval { &$code };
		Psh::Util::print_error($@) if $@ && $@ !~/^SECRET/;
		return (0,@result);
	}

	unless ($pid = fork) { #child
		unless (defined $pid) {
			Psh::Util::print_error_i18n('fork_failed');
			return (-1,0,undef);
		}

		$Psh::OS::Unix::forked_already=1;
		close(READ) if( $pgrp_leader);
		_setup_redirects($options,0);
		POSIX::setpgid(0,$pgrp_leader||$$);
		_give_terminal_to($pgrp_leader||$$) if $fgflag && !$termflag;
		remove_signal_handlers();

		if( ref($code) eq 'CODE') {
			my @tmp=&{$code};
			if (!@tmp or $tmp[0]) {
				CORE::exit(0);
			}
			CORE::exit(1);
		} else {
			{
				if( ! ref $options) {
					exec $code;
				} else {
					$code= shift @$words;
					exec { $code } @$words;
				}
			} # Avoid unreachable warning
			Psh::Util::print_error_i18n('exec_failed',$code);
			CORE::exit(-1);
		}
	}
	POSIX::setpgid($pid,$pgrp_leader||$pid);
	_give_terminal_to($pgrp_leader||$pid) if $fgflag && !$termflag;
	return ($pid,0,undef);
}

sub fork_process {
    my( $code, $fgflag, $string, $options) = @_;
	my ($pid,$sucess,@result)= _fork_process($code,undef,$fgflag,$string,$options);
	return @result if !$pid;
	my $job= Psh::Joblist::create_job($pid,$string);
	if( !$fgflag) {
		my $visindex= Psh::Joblist::get_job_number($job->{pid});
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

	my $job= Psh::Joblist::find_job($job_to_start);

	if(defined($job)) {
		my $pid = $job->{pid};
		my $command = $job->{call};

		if ($command) {
			my $verb= ucfirst(Psh::Locale::get_text('restart'));
			my $qRunning = $job->{running};
			if ($fg_flag) {
				$verb= ucfirst(Psh::Locale::get_text('foreground'));
			} elsif ($qRunning) {
			  # bg request, and it's already running:
			  return;
			}
			my $visindex = Psh::Joblist::get_job_number($pid);
			Psh::Util::print_out("[$visindex] $verb $pid $command\n");

			if($fg_flag) {
				eval { _wait_for_system($pid, 0); };
				Psh::Util::print_debug_class('e',"Error: $@") if $@;
			} elsif( !$qRunning) {
				$job->continue;
			}
		}
	}
}

sub resume_job {
	my $job= shift;

	kill 'CONT', -$job->{pid};
	kill 'CONT', -$job->{pgrp_leader} if $job->{pgrp_leader};
}

# Simply doing backtick eval - mainly for Prompt evaluation
sub backtick {
	my $com=join ' ',@_;
	local $^F=50;
	my ($read,$write)= POSIX::pipe();

	unless(my $pid=fork) {
		POSIX::close($read);
		POSIX::dup2($write,fileno(*STDOUT));
		$^F=$write if ($write>$^F);
		my ($success)= Psh::evl($com);
		CORE::exit(!$success);
	}
	POSIX::close($write);
	my $result='';
	local(*READ);
	open(READ,"<&=$read");
	while(<READ>) {
		$result.=$_;
	}
	close(READ);
	return $result;
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
					   'TERM' => \&Psh::OS::fb_exit_psh,
					   'HUP'  => \&Psh::OS::fb_exit_psh,
					   'SEGV' => 0,
					   'WINCH'=> 0,
					   'ZERO' => 0,
					   );

my @signals= grep { substr($_,0,1) ne '_' } keys %SIG;

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
	Psh::OS::fb_reinstall_resize_handler();
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

	Psh::OS::check_terminal_size();

	$SIG{$sig} = \&_resize_handler;
}

{
	my $debian=-1;
	sub _check_debian {
		if ($debian==-1) {
			if (-r '/etc/debian-version') {
				$debian=1;
			} else {
				$debian=0;
			}
		}
		return $debian;
	}
}

sub get_editor {
	my $file= shift;
	my $suggestion= shift;
	my $editor= $suggestion||$ENV{VISUAL}||$ENV{EDITOR};
	if (_check_debian()) {
		$editor ||='editor';
	} else {
		$editor ||='vi';
	}
	return $editor;
}

# File::Spec

sub canonpath {
    my ($path) = @_;
    $path =~ s|/+|/|g unless($^O eq 'cygwin');     # xx////xx  -> xx/xx
    $path =~ s|(/\.)+/|/|g;                        # xx/././xx -> xx/xx
    $path =~ s|^(\./)+||s unless $path eq "./";    # ./xx      -> xx
    $path =~ s|^/(\.\./)+|/|s;                     # /../../xx -> xx
    $path =~ s|/\Z(?!\n)|| unless $path eq "/";          # xx/       -> xx
    return $path;
}

sub catfile {
    my $file = pop @_;
    return $file unless @_;
    my $dir = catdir(@_);
    $dir .= "/" unless substr($dir,-1) eq "/";
    return $dir.$file;
}

sub catdir {
    my @args = @_;
    foreach (@args) {
        # append a slash to each argument unless it has one there
        $_ .= "/" if $_ eq '' || substr($_,-1) ne "/";
    }
    return canonpath(join('', @args));
}

sub file_name_is_absolute {
	my $file= shift;
	return scalar($file =~ m:^/:s);
}

sub rootdir {
	'/';
}

sub splitdir {
    my ($directories) = @_ ;

    if ( $directories !~ m|/\Z(?!\n)| ) {
        return split( m|/|, $directories );
    }
    else {
        my( @directories )= split( m|/|, "${directories}dummy" ) ;
        $directories[ $#directories ]= '' ;
        return @directories ;
    }
}

sub rel2abs {
    my ($path,$base ) = @_;
 
    # Clean up $path
    if ( ! file_name_is_absolute( $path ) ) {
        # Figure out the effective $base and clean it up.
        if ( !defined( $base ) || $base eq '' ) {
            $base = Psh::getcwd_psh() ;
        }
        elsif ( ! file_name_is_absolute( $base ) ) {
            $base = rel2abs( $base ) ;
        }
        else {
            $base = canonpath( $base ) ;
        }
 
        # Glom them together
        $path = catdir( $base, $path ) ;
    }
 
    return canonpath( $path ) ;
}

1;

__END__


