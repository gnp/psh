package Psh2::Unix;

use POSIX ':signal_h';

sub path_separator { ':' }
sub file_separator { '/' }
sub getcwd {
    my $cwd;
    chomp( $cwd = `/bin/pwd`);
    return $cwd;
}

sub get_path_extension() { return ['']; }

sub get_home_dir {
    my $self= shift;
    my $user= shift || $ENV{USER};
    return (CORE::getpwnam($user))[7];
}

############################################################################
##
## Signal Handling
##
############################################################################

{
    my $sigset_all= POSIX::SigSet->new(SIGTERM);
    my $sigact_term= POSIX::SigAction->new('Psh2::Unix::_term_handler', SIGTERM, SA_NOCLDSTOP|SA_RESTART);
    my $sigact_term_dfl= POSIX::SigAction->new(SIG_DFL, SIGTERM);

    sub setup_signal_handlers {
	POSIX::sigaction(SIGTERM, $sigact_term);
    }

    sub remove_signal_handlers {
	POSIX::sigaction(SIGTERM, $sigact_term_dfl);
    }

    sub _default_handler {
	my $sig= shift;
	give_terminal_to(undef,$$);
	print STDERR "Received SIG$sig in $$\n";
#	$SIG{$sig}= \&_default_handler;
    }

    sub _ignore_handler {
#	$SIG{$_[0]}= \&_ignore_handler;
    }

    sub _ttou_handler {
	give_terminal_to(undef,$$);
    }
    
    sub _term_handler {
	CORE::exit();
    }
}

############################################################################
##
## Execution
##
############################################################################

sub reap_children {
    my ($self)= @_;
    my $returnpid= 0;
    while (($returnpid = CORE::waitpid(-1, POSIX::WNOHANG() |
				           POSIX::WUNTRACED())) > 0) {
	my $job= $self->get_job($returnpid);
	if (defined $job) {
	    $job->_handle_wait_status($?);
	}
    }
}

sub execute {
    my ($self, $tmp)= @_;
    my ($strategy, $how, $options, $words)= @$tmp;

    if ($strategy eq 'execute') {
	{ exec { $how } @$words };
	return -1;
    } elsif ($strategy eq 'builtin') {
	no strict 'refs';
	my $coderef= *{$how.'::execute'};
	return !&{$coderef}($self, $words);
    } elsif ($strategy eq 'language') {
	no strict 'refs';
	my $coderef= *{$how.'::execute'};
	return !&{$coderef}($self, $words);
    }
}

sub fork {
    my ($self, $tmp, $pgrp_leader, $fgflag, $giveterm)= @_;
    my ($strategy, $how, $options, $words)= @$tmp;
    my $pid;

    unless ($pid= fork()) {
	unless (defined $pid) {
	    CORE::exit(2)
	    # Error handling
	}
	remove_signal_handlers();
	_setup_redirects($options);
	POSIX::setpgid( 0, $pgrp_leader || $$ );
	give_terminal_to( $self, $pgrp_leader || $$ ) if $fgflag and $giveterm;
	my @tmp= execute($self, $tmp);
	CORE::exit($tmp[0]);
    }
    POSIX::setpgid( $pid, $pgrp_leader || $pid);
#    give_terminal_to( $self, $pgrp_leader || $pid) if $fgflag and $giveterm;
    return $pid;
}

{
    my $terminal_owner= -1;

    sub give_terminal_to {
	my ($self, $pid)= @_;
	return if $terminal_owner==$pid;
	$terminal_owner= $pid;
	POSIX::tcsetpgrp( fileno STDIN, $pid);
    }
}

sub _setup_redirects {
    my $options= shift;

    return [] if ref $options ne 'ARRAY';

    my @cache=();
    foreach my $option (@$options) {
	if( $option->[0] == Psh2::Parser::T_REDIRECT()) {
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
		POSIX::lseek($tmpfd,0, &POSIX::SEEK_END);
		POSIX::dup2($tmpfd, $type);
		POSIX::close($tmpfd);
	    }
	    if ($^F<$type) { # preserve filedescriptors higher than 2
		$^F=$type;
	    }
	}
    }
    return \@cache;
}

############################################################################
##
## File::Spec
## Copied here as File::Spec pulls in too many other modules
##
############################################################################

sub canonpath {
    my ($self, $path) = @_;
    $path =~ s|/+|/|g unless $^O eq 'cygwin';     # xx////xx  -> xx/xx
    $path =~ s|(/\.)+/|/|g;                        # xx/././xx -> xx/xx
    $path =~ s|^(\./)+||s unless $path eq './';    # ./xx      -> xx
    $path =~ s|^/(\.\./)+|/|s;                     # /../../xx -> xx
    if( $path ne '/' and substr($path,-1) eq '/') {
	return substr($path,0,-1);
    }
    return $path;
}

sub catfile {
    my $self= shift;
    my $file = pop @_;
    return $file unless @_;
    my $dir = catdir($self, @_);
    $dir .= "/" unless substr($dir,-1) eq "/";
    return $dir.$file;
}

sub catfile_fast { return join('/', @_); }
sub catdir_fast { return join('/', @_); }

sub catdir {
    my $self= shift;
    my @args = @_;
    foreach (@args) {
        # append a slash to each argument unless it has one there
        $_ .= "/" if $_ eq '' or substr($_,-1) ne "/";
    }
    return canonpath($self, join('', @args));
}

sub file_name_is_absolute {
    my $self= shift;
    my $file= shift;
    return substr($file,0,1) eq '/';
}

sub rootdir {
    '/';
}

sub splitdir {
    my ( $self, $directories) = @_ ;

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
    my ($self, $path, $base ) = @_;

    if (substr($path,0,1) ne '/') {
        if ( !defined $base or $base eq '' ) {
            $base = $ENV{PWD};
        }
        elsif ( substr($base,0,1) ne '/' ) {
            $base = rel2abs( $self, $base ) ;
        }
	$path= $base.'/'.$path;
    }
    return canonpath( $self, $path ) ;
}


package Psh2::Unix::Job;

sub new {
    my ($class, %self)= @_;
    my $self= \%self;
    die "missing pgrp leader" unless $self->{pid};
    $self->{running}= 1;
    bless $self, $class;
    return $self;
}

sub resume {
    my $self= shift;
    kill 'CONT', -$self->{pid};
    $self->{running}= 1;
}

sub restart {
    my ($self, $fgflag)= @_;
    my $verb;
    my $psh= $self->{psh};

    if ($fgflag) {
	$verb= ucfirst($psh->gt('foreground'));
    } elsif ($self->{running}) {
	return;
    } else {
	$verb= ucfirst($psh->gt('restart'));
    }
    my $visindex= $psh->get_job_number($self->{pid});
    $psh->set_current_job($self->{pid});

    $psh->print("[$visindex] $verb $self->{pid} $self->{desc}\n");

    if ($fgflag) {
	eval {
	    $self->wait_for_finish();
	};
    } elsif (!$self->{running}) {
	$self->resume();
    }
}

sub wait_for_finish {
    my $self= shift;

    my $psh= $self->{psh};
    my $psh_pgrp= CORE::getpgrp();
    my $pid_status= -1;
    my $status= 1;
    my @pids= @{$self->{pids}};
    my $term_pid= $self->{pid} || $pids[$#pids];
    $psh->give_terminal_to($term_pid);
    my $returnpid;
    my @output=();
    while (1) {
	if (!$self->{running}) {
	    $self->resume();
	}
	{
	    $returnpid= CORE::waitpid($pids[$#pids], POSIX::WUNTRACED());
	    $pid_status= $?;
	}
	last if $returnpid < 1;

	if ($psh->{interactive}) {
	    if ($returnpid == $term_pid) {
		push @output, _handle_wait_status($self, $pid_status, 1, 1 );
	    } else {
		my $tmpjob= $psh->get_job($returnpid);
		push @output, _handle_wait_status($tmpjob, $pid_status, 1, 1);
	    }
	} else {
	    if (POSIX::WIFEXITED($pid_status) or
	        POSIX::WIFSIGNALED($pid_status)) {
		$psh->delete_job($returnpid);
	    } elsif (POSIX::WIFSTOPPED($pid_status)) {
		my $tmpjob= $psh->get_job($returnpid);
		$tmpjob->{running}= 0;
		$psh->set_current_job($returnpid);
	    }
	}
	if ($returnpid == $pids[$#pids]) {
	    $status= POSIX::WEXITSTATUS($pid_status);
	    last;
	}
    }
    $psh->give_terminal_to($psh_pgrp);
    $psh->print(@output) if @output;
    return $status==0;
}

sub _handle_wait_status {
    my ($self, $pid_status, $quiet, $collect)= @_;

    my $psh= $self->{psh};
    my $pid= $self->{pid};
    my $verb='';
    my $visindex;

    if (POSIX::WIFEXITED($pid_status)) {
	if ($psh->{interactive}) {
	    my $status= POSIX::WEXITSTATUS($pid_status);
	    if ($status==0) {
		$verb= ucfirst($psh->gt('done')) unless $quiet;
	    } else {
		$verb= ucfirst($psh->gt('error'));
	    }
	    $visindex= $psh->get_job_number($pid);
	}
	$psh->delete_job($pid);
    } elsif (POSIX::WIFSIGNALED($pid_status)) {
	if ($psh->{interactive}) {
	    my $tmp= $psh->gt('terminated');
	    $verb = "\u$tmp (SIG" .POSIX::WTERMSIG($pid_status).')';
	    $visindex= $psh->get_job_number($pid);
	}
	$psh->delete_job($pid);
    } elsif (POSIX::WIFSTOPPED($pid_status)) {
	$self->{running}= 0;
	$psh->set_current_job($pid);
	if ($psh->{interactive}) {
	    my $tmp= $psh->gt('stopped');
	    $verb = "\u$tmp (SIG". POSIX::WSTOPSIG($pid_status).')';
	    $visindex= $psh->get_job_number($pid);
	}
    }
    if ($verb and $psh->{interactive} and $visindex>0) {
	my $line="[$visindex] $verb $pid $self->{desc}\n";
	return $line if $collect;
	$psh->print($line);
    }
    return '';
}

1;
