package Psh::Util;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

use Cwd;
use Cwd 'chdir';
use Config;
use Psh::OS;

require Exporter;

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

@ISA= qw(Exporter);

@EXPORT= qw( );
@EXPORT_OK= qw( starts_with ends_with);
%EXPORT_TAGS = ( all => [qw(print_warning print_debug print_error
							print_out print_error_i18n print_out_i18n
							which abs_path)] );

Exporter::export_ok_tags('all'); # Add EXPORT_TAGS to EXPORT_OK

sub print_warning
{
	print STDERR @_;
}

sub print_debug
{
	print STDERR @_ if $Psh::debugging;
}

sub print_error
{
	print STDERR @_;
}

#
# print_i18n( stream, key, args)
# print_out_i18n( key, args)
# print_error_i18n( key, args)
#
# The print..._i18n suite of functions will fetch the
# text from the %text hash, replace %1 with the first arg,
# %2 with the second and so on and then print it out
#

sub _print_i18n
{
	my( $stream, $text, @rest) = @_;
	$text= $Psh::text{$text};
	# This was looping over 0 and 1 and replacing %0 and %1
	for( my $i=1; $i<=@rest; $i++)
	{
		$text=~ s/\%$i/$rest[$i-1]/g; # removed o from flags huggie
	}
	print $stream $text;
}


sub print_error_i18n
{
	_print_i18n(*STDERR,@_);
}

sub print_out_i18n
{
	_print_i18n(*STDOUT,@_);
}

sub print_out
{
	print STDOUT @_;
}



#
# string abs_path(string DIRECTORY)
#
# expands the argument DIRECTORY into a full, absolute pathname.
#

eval "use Cwd 'fast_abs_path';";
if (!$@) {
	print_debug("Using &Cwd::fast_abs_path()\n");
	sub abs_path { return fast_abs_path(@_); }
} else {
    sub abs_path {
		my $dir = shift;
		my $FS= Psh::OS::FILE_SEPARATOR();
		
		$dir = '~' unless defined $dir and $dir ne '';
		
		if ($dir =~ m|^(~([a-zA-Z0-9-]*))(.*)$|) {
			my $user = $2; 
			my $rest = $3;
			
			my $home;
			
			if ($user eq '') { $home = $ENV{HOME}; }
			else             { $home = get_home_dir($user);(getpwnam($user))[7]; }
			
			if ($home) { $dir = "$home$rest"; } # If user's home not found, leave it alone.
		}

		if( !Psh::OS::is_path_absolute($dir)) {
			$dir = cwd . $FS. $dir
		}
		
		return $dir;
	}
}


#
# string which(string FILENAME)
#
# search for an occurrence of FILENAME in the current path as given by 
# $ENV{PATH}. Return the absolute filename if found, or undef if not.
#

{
	#
	# "static variables" for which() :
	#

	my $last_path_cwd = '';
	my %hashed_cmd    = ();

	sub which
    {
		my $cmd      = shift;
		my $FS= Psh::OS::FILE_SEPARATOR();
		my $qFS= "\\".$FS;

		print_debug("[which $cmd]\n");

		if ($cmd =~ m|$qFS|) {
			my $try = abs_path($cmd);
			if ((-x $try) and (! -d _)) { return $try; }
			return undef;
		}

		if ($last_path_cwd ne ($ENV{PATH} . cwd())) {
			$last_path_cwd = $ENV{PATH} . cwd();
			@Psh::absed_path    = ();
			%hashed_cmd    = ();

			my @path = split(Psh::OS::PATH_SEPARATOR(), $ENV{PATH});

			foreach my $dir (@path) {
				push @Psh::absed_path, abs_path($dir);
			}
		}

		if (exists($hashed_cmd{$cmd})) { return $hashed_cmd{$cmd}; }

		my @path_extension=Psh::OS::get_path_extension();

		foreach my $dir (@Psh::absed_path) {
			my $try = $dir.$FS.$cmd;
			foreach my $ext (@path_extension) {
				if ((-x $try.$ext) and (!-d _)) { 
					$hashed_cmd{$cmd} = $try.$ext;
					return $try.$ext; 
				}
			}
		}
      
		$hashed_cmd{$cmd} = undef;

		return undef;
	}
}

#
# starts_with( text, prefix)
# Returns true if text starts with prefix
#

sub starts_with {
	my ($text, $prefix) = @_;

	return length($text)>=length($prefix) &&
		substr($text,0,length($prefix)) eq $prefix;
}

#
# ends_with( text, suffix)
# Returns true if text ends with suffix
#

sub ends_with {
	my ( $text, $suffix) = @_;

	return length($text)>=length($suffix) &&
		substr($text,-length($suffix)) eq $suffix;
}

1;

__END__

=head1 NAME

Psh::Utils - Containing certain Psh utility functions

=head1 SYNOPSIS

  use Psh::Utils (:all);

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
# End:


