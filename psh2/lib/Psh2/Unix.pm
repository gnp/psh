package Psh2::Unix;

require POSIX;

sub path_separator { ':' }
sub file_separator { '/' }
sub getcwd {
    my $cwd;
    chomp( $cwd = `pwd`);
    return $cwd;
}

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
	_give_terminal_to($$);
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

sub execute {
    my $tmp= shift;
    my ($strategy, $how, $options, $words)= @$tmp;

    if ($strategy eq 'execute') {
	{ exec { $how } @$words };
	return -1;
    } elsif ($strategy eq 'builtin') {
	no strict 'refs';
	my $coderef= *{$how.'::execute'};
	return &{$coderef}($words);
    }
}

sub fork {
    my ($tmp, $pgrp_leader, $fgflag, $termflag)= @_;
    my ($strategy, $how, $options, $words)= @$tmp;
    my $pid;

    unless ($pid= fork()) {
	unless (defined $pid) {
	    CORE::exit(1)
	    # Error handling
	}
	_setup_redirects($options);
	POSIX::setpgid( 0, $pgrp_leader || $$ );
	_give_terminal_to( $pgrp_leader || $$ ) if $fgflag and !$termflag;
	remove_signal_handlers();
	my @tmp= execute($tmp);
	CORE::exit($tmp[0]);
    }
    POSIX::setpgid( $pid, $pgrp_leader || $pid);
    _give_terminal_to( $pgrp_leader || $pid) if $fgflag and !$termflag;
    return $pid;
}

{
    my $terminal_owner= -1;

    sub _give_terminal_to {
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

sub get_path_extension() { return ['']; }

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

1;
