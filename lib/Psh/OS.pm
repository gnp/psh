package Psh::OS;

use strict;
use vars qw($VERSION $AUTOLOAD $ospackage);
use Carp 'croak';
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
	croak "Function `$AUTOLOAD' in Psh::OS does not exist." unless
		ref *{"${ospackage}::$AUTOLOAD"}{CODE} eq 'CODE';
	*$AUTOLOAD=  *$name;
	goto &$AUTOLOAD;
}

#
# The following code is here because it is most probably
# portable across at least a large number of platforms
# If you need to override them, then modify the symbol
# table :-)


# Simply doing backtick eval - mainly for Prompt evaluation
sub backtick {
	return `@_`;
}

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

#
# The Perl builtin glob STILL uses csh, furthermore it is
# not possible to supply a base directory... so I guess this
# is faster
#
sub glob {
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
		my $prefix= $1;
		$pattern= $2;
		$prefix=~ s:/$::;
	    $dir= File::Spec->catdir($dir,$prefix);
		$pattern=~s/\\/\\\\/g;
		$pattern=~s/\./\\./g;
		$pattern=~s/\*/[^\/]*/g;
		$pattern=~s/\?/./g;
		$pattern='[^\.]'.$pattern if( substr($pattern,0,2) eq '.*');
		@result= map { substr($_,$tlen) } _recursive_glob($pattern,$dir);
	} elsif( $pattern=~ m:/:) {
		# Too difficult to simulate, so use slow variant
		my $old=$ENV{PWD};
		chdir $dir;
		@result= CORE::glob($pattern);
		chdir $old;
	} else {
		# The fast variant for simple matches
		$pattern=~s/\\/\\\\/g;
		$pattern=~s/\./\\./g;
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

sub signal_name {
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

sub signal_description {
	my $signal_name= signal_name(shift);
	my $desc= $Psh::text{sig_description}->{$signal_name};
   	if( defined($desc) and $desc) {
		
		return "SIG$signal_name - $desc";
	}
	return "signal $signal_name";
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


