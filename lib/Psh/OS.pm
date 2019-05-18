package Psh::OS;

use strict;

my $ospackage;

BEGIN {
	if ($^O eq 'MSWin32') {
		$ospackage='Psh::OS::Win';
		require Psh::OS::Win;
		die "Could not find OS specific package $ospackage: $@" if $@;
	} else {
		$ospackage='Psh::OS::Unix';
		require Psh::OS::Unix;
		die "Could not find OS specific package $ospackage: $@" if $@;
	}
}

sub AUTOLOAD {
	no strict;
	$AUTOLOAD=~ s/.*:://;
	my $name="${ospackage}::$AUTOLOAD";
	$name="Psh::OS::fb_$AUTOLOAD" unless ref *{$name}{CODE} eq 'CODE';
	unless (ref *{$name}{CODE} eq 'CODE') {
		require Carp;
		eval {
			Carp::croak("Function `$AUTOLOAD' in Psh::OS does not exist.");
		};
	}
	*$AUTOLOAD=  *$name;
	goto &$AUTOLOAD;
}

#
# The following code is here because it is most probably
# portable across at least a large number of platforms
# If you need to override them, then modify the symbol
# table :-)

# recursive glob function used for **/anything glob
sub _recursive_glob {
	my( $pattern, $dir)= @_;
	opendir( DIR, $dir) || return ();
	my @files= readdir(DIR);
	closedir( DIR);
	my @result= map { catdir($dir,$_) }
	  grep { /^$pattern$/ } @files;
	foreach my $tmp (@files) {
		my $tmpdir= catdir($dir,$tmp);
		next if ! -d $tmpdir || !no_upwards($tmp);
		push @result, _recursive_glob($pattern, $tmpdir);
	}
	return @result;
}

sub _escape {
	my $text= shift;
	if ($] >= 5.005) {
		$text=~s/(?<!\\)([^a-zA-Z0-9\*\?])/\\$1/g;
	} else {
		# TODO: no escaping yet
	}
	return $text;
}

#
# The Perl builtin glob STILL uses csh, furthermore it is
# not possible to supply a base directory... so I guess this
# is faster
#
sub fb_glob {
	my( $pattern, $dir, $already_absed) = @_;

	return () unless $pattern;

	my @result;
	if( !$dir) {
		$dir=$ENV{PWD};
	} else {
		$dir=Psh::Util::abs_path($dir) unless $already_absed;
	}
	return unless $dir;

	# Expand ~
	my $home= $ENV{HOME}||get_home_dir();
	if ($pattern eq '~') {
		$pattern=$home;
	} else {
		$pattern=~ s|^\~/|$home/|;
		$pattern=~ s|^\~([^/]+)|&get_home_dir($1)|e;
	}

	return $pattern if $pattern !~ /[*?]/;
	
	# Special recursion handling for **/anything globs
	if( $pattern=~ m:^([^\*]+/)?\*\*/(.*)$: ) {
		my $tlen= length($dir)+1;
		my $prefix= $1||'';
		$pattern= $2;
		$prefix=~ s:/$::;
	    $dir= catdir($dir,$prefix);
		$pattern=_escape($pattern);
		$pattern=~s/\*/[^\/]*/g;
		$pattern=~s/\?/./g;
		$pattern='[^\.]'.$pattern if( substr($pattern,0,2) eq '.*');
		@result= map { substr($_,$tlen) } _recursive_glob($pattern,$dir);
	} elsif( $pattern=~ m:/:) {
		# Too difficult to simulate, so use slow variant
		my $old=$ENV{PWD};
		CORE::chdir $dir;
		$pattern=_escape($pattern);
		@result= eval { CORE::glob($pattern); };
		CORE::chdir $old;
	} else {
		# The fast variant for simple matches
		$pattern=_escape($pattern);
		$pattern=~s/\*/.*/g;
		$pattern=~s/\?/./g;
		$pattern='[^\.]'.$pattern if( substr($pattern,0,2) eq '.*');
		
		opendir( DIR, $dir) || return ();
		@result= grep { /^$pattern$/ } readdir(DIR);
		closedir( DIR);
	}
	return @result;
}

#
# string signal_name( int )
# Looks up the name of a signal
#

sub fb_signal_name {
	my $signalnum = shift;
	require Config;
	my @numbers= split ',',$Config::Config{sig_num};
	@numbers= split ' ',$Config::Config{sig_num} if( @numbers==1);
	# Strange incompatibility between perl versions

	my @names= split ' ',$Config::Config{sig_name};
	for( my $i=0; $i<$#numbers; $i++)
	{
		return $names[$i] if( $numbers[$i]==$signalnum);
	}
	return $signalnum;
}

#
# string signal_description( int signal_number | string signal_name )
# returns a descriptive name for the POSIX signals
#

sub fb_signal_description {
	my $signal_name= signal_name(shift);
	my $desc= Psh::Locale::get_text('sig_description')->{$signal_name};
   	if( defined($desc) and $desc) {
		return "SIG$signal_name - $desc";
	}
	return "signal $signal_name";
}

# Return a name for a temp file
# Legacy security risk, but leaving in case
# anyone's using it. We're already loading
# POSIX anyway, and it gives its own warning.
sub fb_tmpnam {
	return POSIX::tmpnam();
}
sub fb_tmpfile {
	require IO::File;
	return IO::File::new_tmpfile();
}

sub fb_get_window_size {}
sub fb_remove_signal_handlers {1}
sub fb_setup_signal_handlers {1}
sub fb_setup_sigsegv_handler {1}
sub fb_setup_readline_handler {1}
sub fb_reap_children {1}
sub fb_abs_path { undef }

#
# Exit psh - you won't believe it, but exit needs special treatment on
# MacOS
#
sub fb_exit_psh {
	Psh::Util::print_debug_class('i',"[Psh::OS::exit_psh() called]\n");
	Psh::save_history();
	$ENV{SHELL} = $Psh::old_shell if $Psh::old_shell;
	CORE::exit($_[0]) if $_[0];
	CORE::exit(0);
}

sub fb_getcwd_psh {
	eval { require Cwd; };
	return eval { Cwd::getcwd(); } || '';
}

sub fb_LOCK_SH() { 1; }
sub fb_LOCK_EX() { 2; }
sub fb_LOCK_NB() { 4; }
sub fb_LOCK_UN() { 8; }

sub fb_lock {
	my $file= shift;
	my $type= shift || Psh::OS::LOCK_SH();
	my $count=3;
	my $status=0;
	while ($count-- and !$status) {
		$status= flock($file, $type| Psh::OS::LOCK_NB());
	}
	return $status;
}

sub fb_unlock {
	my $file= shift;
	flock($file, Psh::OS::LOCK_UN()| Psh::OS::LOCK_NB());
}

sub fb_reinstall_resize_handler { 1; }

{
	my $handler_type=0;

	sub fb_install_resize_handler {
		eval '$Psh::term->get_screen_size()';
		unless ($@) {
			$handler_type=3;
			return;
		}
		eval 'use Term::Size;';
		if ($@) {
			eval 'use Term::ReadKey;';
			unless ($@) {
				$handler_type=2;
			}
		} else {
			$handler_type=1;
		}
	}


	sub fb_check_terminal_size {
		my ($cols,$rows);

		if ($handler_type==0) {
			return;
		} elsif ($handler_type==3) {
			eval {
				($rows,$cols)= $Psh::term->get_screen_size();
			};
		} elsif ($handler_type==1) {
			eval {
				($cols,$rows)= Term::Size::chars();
			};
		} elsif ($handler_type==2) {
			eval {
				($cols,$rows)= Term::ReadKey::GetTerminalSize(*STDOUT);
			};
		}

		if($cols && $rows && ($cols > 0) && ($rows > 0)) {
			$ENV{COLUMNS} = $cols;
			$ENV{LINES}   = $rows;
			if( $Psh::term) {
				$Psh::term->Attribs->{screen_width}=$cols-1;
			}
			# for ReadLine::Perl
		}
	}
}


# File::Spec
#
# We add the necessary functions directly because:
# 1) Changes to File::Spec might be fatal to psh's file location mechanisms
# 2) File::Spec loads unwanted modules
# 3) We don't need it anyway as we need platform-specific OS modules
#    anyway
#
# Normally I wouldn't do it - but this is a shell and memory
# consumption and startup time is worth something for everyday work...

sub fb_no_upwards {
    return grep(!/^\.{1,2}\Z(?!\n)/s, @_);
}


1;

__END__

=head1 NAME

Psh::OS - Wrapper class for OS dependant stuff


=head1 SYNOPSIS

	use Psh::OS;

=head1 DESCRIPTION

TBD

=head1 AUTHOR

Markus Peter, warp@spin.de

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


