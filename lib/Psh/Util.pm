package Psh::Util;

use strict;

require Psh::OS;

%Psh::Util::command_hash=();
%Psh::Util::path_hash=();

sub print_warning
{
	print STDERR @_;
}

#
# Print unclassified debug output
#
sub print_debug
{
	print STDERR @_ if $Psh::debugging && $Psh::debugging =~ /o/;
}

#
# Print classified debug output
#
sub print_debug_class
{
	my $class= shift;
	print STDERR @_ if $Psh::debugging and
	  ($Psh::debugging eq '1' or
	   $Psh::debugging =~ /$class/);
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
	return unless $stream;
	$text= Psh::Locale::get_text($text);
	for( my $i=1; $i<=@rest; $i++)
	{
		$text=~ s/\%$i/$rest[$i-1]/g;
	}
	print $stream $text;
}


sub print_error_i18n
{
	_print_i18n(*STDERR,@_);
}

sub print_warning_i18n
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

# Copied from readline.pl - pretty prints a list in columns
sub print_list
{
	my @list= @_;
    return unless @list;
    my ($lines, $columns, $mark, $index);

    ## find width of widest entry
    my $maxwidth = 0;
	my $screen_width=$ENV{COLUMNS};

	if (ref $list[0] and ref $list[0] eq 'ARRAY') {
		$maxwidth= $list[1];
		@list= @{$list[0]};
	}

	unless ($maxwidth) {
		grep(length > $maxwidth && ($maxwidth = length), @list);
	}
	$maxwidth++;

	$columns = $maxwidth >= $screen_width?1:int($screen_width / $maxwidth);

    ## if there's enough margin to interspurse among the columns, do so.
    $maxwidth += int(($screen_width % $maxwidth) / $columns);

    $lines = int((@list + $columns - 1) / $columns);
    $columns-- while ((($lines * $columns) - @list + 1) > $lines);

    $mark = $#list - $lines;
    for (my $l = 0; $l < $lines; $l++) {
        for ($index = $l; $index <= $mark; $index += $lines) {
			my $tmp= my $item= $list[$index];
			$tmp=~ s/\001(.*?)\002//g;
			$item=~s/\001//g;
			$item=~s/\002//g;
			my $diff= length($item)-length($tmp);
			my $dispsize= $maxwidth+$diff;
            print_out(sprintf("%-${dispsize}s", $item));
        }
		if ($index<=$#list) {
			my $item= $list[$index];
			$item=~s/\001//g; $item=~s/\002//g;
			print_out($item);
		}
        print_out("\n");
    }
}

sub abs_path {
	my $dir= shift;
	return undef unless $dir;
	return $Psh::Util::path_hash{$dir} if $Psh::Util::path_hash{$dir};
	my $result= Psh::OS::abs_path($dir);
	unless ($result) {
		if ($dir eq '~') {
			$result= Psh::OS::get_home_dir();
		} elsif ( substr($dir,0,2) eq '~/') {
			substr($dir,0,1)= Psh::OS::get_home_dir();
		} elsif ( substr($dir,0,1) eq '~' ) {
			my $fs= $Psh::OS::FILE_SEPARATOR;
			my ($user)= $dir=~/^\~(.*?)$fs/;
			if ($user) {
				substr($dir,0,length($user)+1)= Psh::OS::get_home_dir($user);
			}
		}
		unless ($result) {
			my $tmp= Psh::OS::rel2abs($dir,$ENV{PWD});

			my $old= $ENV{PWD};
			if ($tmp and -r $tmp) {
				if (-d $tmp and -x _) {
					if ( CORE::chdir($tmp)) {
						$result = Psh::OS::getcwd_psh();
						if (!CORE::chdir($old)) {
						    print STDERR "Could not change directory back to $old!\n";
						    CORE::chdir(Psh::OS::get_home_dir())
						}
					}
				} else {
					$result= $tmp;
				}
			}
#  			if ($tmp and !$result) {
#  				local $^W=0;
#  				local $SIG{__WARN__}= {};
#  				eval {
#  					$result= Cwd::abs_path($tmp);
#  				};
#  				print_debug_class('e',"(abs_path) Error: $@") if $@;
#  			}
			return undef unless $result;
		}
		if ($result) {
			$result.='/' unless $result=~ m:[/\\]:;  # abs_path strips / from letter: on Win
		}
	}
	$Psh::Util::path_hash{$dir}= $result if Psh::OS::file_name_is_absolute($dir);
	return $result;
}

sub recalc_absed_path {
	@Psh::absed_path    = ();
	%Psh::Util::command_hash    = ();

	my @path = split($Psh::OS::PATH_SEPARATOR, $ENV{PATH});

	eval {
		foreach my $dir (@path) {
			next unless $dir;
			my $dir= Psh::Util::abs_path($dir);
			next unless -r $dir and -x _;
			push @Psh::absed_path, $dir;
		}
	};
	print_debug_class('e',"(recalc_absed_path) Error: $@") if $@;
	# Without the eval Psh might crash if the directory
	# does not exist
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
	my $FS=$Psh::OS::FILE_SEPARATOR;
	my $tmp= quotemeta($FS);
	my $re1="$tmp";
	my $re2="^(.*)$tmp([^$tmp]+)\$";

	if ($]>=5.005) {
		eval {
			$re1= qr{$re1}o;
			$re2= qr{$re2}o;
		};
		print_debug_class('e',"(util::before which) Error: $@") if $@;
	}

	sub which
    {
		my $cmd= shift;
		my $all= shift;
		return undef unless $cmd;


		if ($cmd =~ m|$re1|o ) {
			$cmd =~ m|$re2|o;
			my $path_element= $1 || '';
			my $cmd_element=  $2 || '';
			return undef unless $path_element and $cmd_element;
			$path_element=Psh::Util::abs_path($path_element);
			return undef unless $path_element;
			my $try= Psh::OS::catfile($path_element,$cmd_element);
			if ((-x $try) and (! -d _)) { return $try; }
			return undef;
		}

		return $Psh::Util::command_hash{$cmd} if exists $Psh::Util::command_hash{$cmd} and !$all;

		if ($cmd !~ m/$Psh::which_regexp/) { return undef; }

		if ($last_path_cwd ne ($ENV{PATH} . $ENV{PWD})) {
			$last_path_cwd = $ENV{PATH} . $ENV{PWD};

			recalc_absed_path();
		}

		my @path_extension=Psh::OS::get_path_extension();
		my @all=();

		foreach my $dir (@Psh::absed_path) {
			next unless $dir;
			my $try = Psh::OS::catfile($dir,$cmd);
			foreach my $ext (@path_extension) {
				if ((-x $try.$ext) and (!-d _)) {
					$Psh::Util::command_hash{$cmd} = $try.$ext unless $all;
					return $try.$ext unless $all;
					push @all, $try.$ext;
				}
			}
		}
		if ($all and @all) {
			return @all;
		}
		$Psh::Util::command_hash{$cmd} = undef; # no delete by purpose

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

#
# list parse_hosts_file( text)
# 
# Gets a standard hosts file as input and returns
# a list of the hostnames mentioned in the file
#
sub parse_hosts_file {
	my $text= shift;
	my @lines= split( /\n|\r|\r\n/, $text);
	my @result= ();
	foreach my $line (@lines) {
		next if $line=~/^\s*$/;   # Skip blank lines
		next if $line=~/^\s*\#/;  # Skip comment lines
		$line=~/^\s*\S+\s(.*)$/;
		my $rest= $1;
		push @result, grep { length($_)>0 } split( /\s/, $rest);
	}
	return @result;
}

#
# char prompt( string allowedchars, string prompt)
# prompts the user until he answers with one of the
# allowed characters
#
sub prompt {
	my $allowed= shift;
	$allowed= "^[$allowed]\$";
	my $text= shift;
	my $line='';

	do {
		print $text;
		$line=<STDIN>;
	} while (!$line || lc($line) !~ $allowed);
	chomp $line;
	return lc($line);
}


1;

__END__

