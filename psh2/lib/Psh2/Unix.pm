package Psh2::Unix;

sub path_separator { ':' }
sub file_separator { '/' }
sub getcwd {
    my $cwd;
    chomp( $cwd = `pwd`);
    return $cwd;
}

sub get_path_extension() { return ['']; }


############################################################################
##
## Signal Handling
##
############################################################################

{
    my @signals= grep { substr($_,0,1) ne '_' } keys %SIG;
    my %special_handlers=
      (
       CHLD => \&_ignore_handler,
       CLD  => \&_ignore_handler,
       TERM => \&_term_handler,
       INT  => 0,
       SEGV => 0,
       WINCH => 0,
       ZERO => 0,
      );

    sub setup_signal_handlers {
	foreach my $sig (@signals) {
	    if (exists $special_handlers{$sig}) {
		if (ref $special_handlers{$sig}) {
		    $SIG{$sig}= $special_handlers{$sig};
		}
		next;
	    }
	    $SIG{$sig}= \&_default_handler;
	}
    }

    sub remove_signal_handlers {
	foreach my $sig (@signals) {
	    next if exists $special_handlers{$sig} and !ref $special_handlers{$sig};
	    $SIG{$sig}= 'DEFAULT';
	}
    }

    sub _default_handler {
	my $sig= shift;
	give_terminal_to(undef,$$);
	print STDERR "Received SIG$sig in $$\n";
	$SIG{$sig}= \&_default_handler;
    }

    sub _ignore_handler {
	my $sig= shift;
	$SIG{$sig}= \&_ignore_handler;
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
	    $job->handle_wait_status($?);
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
	return &{$coderef}($self,$words);
    }
}

sub fork {
    my ($self, $tmp, $pgrp_leader, $fgflag, $termflag)= @_;
    my ($strategy, $how, $options, $words)= @$tmp;
    my $pid;

    unless ($pid= fork()) {
	unless (defined $pid) {
	    CORE::exit(1)
	    # Error handling
	}
	_setup_redirects($options);
	POSIX::setpgid( 0, $pgrp_leader || $$ );
	give_terminal_to( $self, $pgrp_leader || $$ ) if $fgflag and !$termflag;
	remove_signal_handlers();
	my @tmp= execute($self, $tmp);
	CORE::exit($tmp[0]);
    }
    POSIX::setpgid( $pid, $pgrp_leader || $pid);
    give_terminal_to( $self, $pgrp_leader || $pid) if $fgflag and !$termflag;
    return $pid;
}

{
    my $terminal_owner= -1;

    sub give_terminal_to {
	my $self= shift;
	my $pid= shift;
	return if $terminal_owner==$pid;
	$terminal_owner= $pid;
	local $SIG{TSTP}= 'IGNORE';
	local $SIG{TTIN}= 'IGNORE';
	local $SIG{TTOU}= 'IGNORE';
	local $SIG{CHLD}= 'IGNORE';
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
    if ( !file_name_is_absolute( $path ) ) {
        # Figure out the effective $base and clean it up.
        if ( !defined $base or $base eq '' ) {
            $base = Psh2::getcwd() ;
        }
        elsif ( !file_name_is_absolute( $base ) ) {
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


package Psh2::Unix::Job;

sub new {
    my ($class, %self)= @_;
    my $self= \%self;
    die "missing pgrp leader" unless $self->{pgrp_leader};
    $self->{running}= 1;
    bless $self, $class;
    return $self;
}

sub resume {
    my $self= shift;
    kill 'CONT', -$self->{pgrp_leader};
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
    my $visindex= $psh->get_job_number($self->{pgrp_leader});
    $psh->set_current_job($visindex-1);

    $psh->print("[$visindex] $verb $self->{pgrp_leader} $self->{desc}\n");

    if ($fgflag) {
	eval {
	    $self->wait_for_finish(0);
	};
    } elsif (!$self->{running}) {
	$self->resume();
    }
}

sub wait_for_finish {
    my $self= shift;
    my $quiet= shift;

    my $psh_pgrp= CORE::getpgrp();
    my $pid_status= -1;
    my $status= 1;
    my @pids= @{$self->{pids}};
    my $term_pid= $self->{pgrp_leader} || $pids[$#pids];
    $self->{psh}->give_terminal_to($term_pid);
    my $returnpid;
    my $output='';
    while (1) {
	if (!$self->{running}) {
	    $self->resume();
	}
	{
	    $returnpid= CORE::waitpid($pids[$#pids], POSIX::WUNTRACED());
	    $pid_status= $?;
	}
	last if $returnpid < 1;

	$output.= handle_wait_status($self, $pid_status, $quiet, 1 );
	if ($returnpid == $pids[$#pids]) {
	    $status= POSIX::WEXITSTATUS($pid_status);
	    last;
	}
    }
    $self->{psh}->give_terminal_to($psh_pgrp);
    $self->{psh}->print($output) if $output;
    return $status==0;
}

sub handle_wait_status {
    my ($self, $pid_status, $quiet, $collect)= @_;
    # Have to obtain these before we potentially delete the job
    my $psh= $self->{psh};
    my $command = $self->{desc};
    my $pid= $self->{pgrp_leader};
    my $visindex= $psh->get_job_number($pid);
    my $verb='';
    
    if (POSIX::WIFEXITED($pid_status)) {
	my $status= POSIX::WEXITSTATUS($pid_status);
	if ($status==0) {
	    $verb= ucfirst($psh->gt('done')) unless $quiet;
	} else {
	    $verb= ucfirst($psh->gt('error'));
	}
	$psh->delete_job($pid);
    } elsif (POSIX::WIFSIGNALED($pid_status)) {
	my $tmp= $psh->gt('terminated');
	$verb = "\u$tmp (SIG" .POSIX::WTERMSIG($pid_status).')';
	$psh->delete_job($pid);
    } elsif (POSIX::WIFSTOPPED($pid_status)) {
	my $tmp= $psh->gt('stopped');
	$verb = "\u$tmp (SIG". POSIX::WSTOPSIG($pid_status).')';
	$self->{running}= 0;
    }
    if ($verb && $visindex>0) {
	my $line="[$visindex] $verb $pid $command\n";
	return $line if $collect;
	$psh->print($line);
    }
    return '';
}

1;
