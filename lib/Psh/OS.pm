package Psh::OS;

use strict;
use vars qw($VERSION $AUTOLOAD $ospackage);
use Cwd;
use Config;
use File::Spec;

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

$ospackage="Psh::OS::Unix";

$ospackage="Psh::OS::Mac" if( $^O eq "MacOS");
$ospackage="Psh::OS::Win" if( $^O eq "MSWin32");

eval "use $ospackage";
die "Could not find OS specific package $ospackage: $@" if( $@);

sub AUTOLOAD {
	$AUTOLOAD=~ s/.*:://;
	no strict 'refs';
	my $name="${ospackage}::$AUTOLOAD";
	$name="Psh::OS::fb_$AUTOLOAD" unless ref *{$name}{CODE} eq 'CODE';
	require Carp;
	Carp::croak "Function `$AUTOLOAD' in Psh::OS does not exist." unless
		ref *{$name}{CODE} eq 'CODE';
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
	my @result= map { File::Spec->catdir($dir,$_) }
	                     grep { /^$pattern$/ } @files;
	foreach my $tmp (@files) {
		my $tmpdir= File::Spec->catdir($dir,$tmp);
		next if ! -d $tmpdir || !File::Spec->no_upwards($tmp);
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
	my( $pattern, $dir) = @_;
	my @result;
	if( !$dir) {
		$dir=$ENV{PWD};
	} else {
		$dir=Psh::Util::abs_path($dir);
	}

	# Expand ~
	my $home= $ENV{HOME}||get_home_dir();
	$pattern=~ s|^\~/|$home/|;
    $pattern=~ s|^\~([^/]+)|&get_home_dir($1)|e;

	return $pattern if $pattern !~ /[*?]/;
	
	# Special recursion handling for **/anything globs
	if( $pattern=~ m:^([^\*]+/)?\*\*/(.*)$: ) {
		my $tlen= length($dir)+1;
		my $prefix= $1||'';
		$pattern= $2;
		$prefix=~ s:/$::;
	    $dir= File::Spec->catdir($dir,$prefix);
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
	my @numbers= split ',',$Config{sig_num};
	@numbers= split ' ',$Config{sig_num} if( @numbers==1);
	# Strange incompatibility between perl versions

	my @names= split ' ',$Config{sig_name};
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
	my $desc= $Psh::text{sig_description}->{$signal_name};
   	if( defined($desc) and $desc) {
		return "SIG$signal_name - $desc";
	}
	return "signal $signal_name";
}

# Return a name for a temp file

sub fb_tmpnam {
	return POSIX::tmpnam();
}

sub fb_get_window_size {}
sub fb_remove_signal_handlers {1}
sub fb_setup_signal_handlers {1}
sub fb_setup_sigsegv_handler {1}
sub fb_setup_readline_handler {1}
sub fb_reinstall_resize_handler {1}
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
	return Cwd::getcwd();
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


