package Psh::Prompt;

use strict;
use vars qw(%prompt_vars $VERSION);
use Cwd;

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

#
# string prompt_string(TEMPLATE)
#
# Construct a prompt string from TEMPLATE.
#

my $default_prompt='\s% ';

%prompt_vars = (
	'd' => sub {
			my ($wday, $mon, $mday) = (localtime)[6, 4, 3];
			$wday = $Psh::wday[$wday];
			$mon  = $Psh::mon[$mon];
			return "$wday $mon $mday";
		},
	'E' => sub { return "\e"} ,
	'h' => sub { return $Psh::host; },
	'H' => sub { return $Psh::longhost; },
	's' => sub {
			my $shell = $Psh::bin;
			$shell =~ s/^.*\///;
			return $shell;
		},
	'S' => sub { return "\0" }, # extends to \
	'n' => sub { return "\n" },
	't' => sub {
			my ($hour, $min, $sec) = (localtime)[2, 1, 0];
			return sprintf("%02d:%02d:%02d", $hour, $min, $sec);
		},
	'u' => sub {
			# Camel, 2e, p. 172: 'getlogin'.
			return getlogin || (getpwuid($>))[0] || "uid$>";
		},
	'w' => sub { 
		    my $dir= cwd;
			my $home= Psh::OS::get_home_dir();
			if( $home) {
				$dir =~ s/^$home/\~/;
			}
		    return $dir;
		},
	'W' => sub {
		    my $dir = cwd;
			$dir =~ s/^.*\///;
			return $dir||'/';
		},
	'#' => sub { return $Psh::cmd; },
	'$' => sub { return ($> ? '$' : '#'); },
	'[' => sub { return ''},
	']' => sub { return ''},
);


sub prompt_helper {
	my $code= shift;
	my $var = $prompt_vars{$code};
	my $sub;

	if (ref $var eq 'CODE') {
		$sub = &$var();
	} elsif($code =~ /^[0-9]+$/) {
		$sub= chr(oct($code));
	} elsif($code =~ /^\:[0-9]+$/) {
		$sub= chr($code);
	} elsif($code =~ /^0x/) {
		$sub= chr(hex($code));
	} else {
		print_warning_i18n('prompt_unknown_escape',$code,$Psh::bin);
		$sub = ''
	}
	
	{
		local $1;
		if ($sub =~ m/\\([^\\])/) {
			print_warning_i18n('prompt_expansion_error',$code,
							   $1, $Psh::bin);
			$sub =~ s/\\[^\\]//g;
		}
	}
	return $sub;
}

sub prompt_string
{
	my $prompt_templ = shift;
	my $temp;

	#
	# First, get the prompt string from a subroutine or from the default:
	#

	if (ref($prompt_templ) eq 'CODE') { # If it is a subroutine,
		$temp = &$prompt_templ();
	} elsif (ref($prompt_templ)) {      # If it isn't a scalar
		print_warning_i18n('prompt_wrong_type',$Psh::bin);
		$temp = $default_prompt;
	} else {
		$temp = $prompt_templ;
	}

	#
	# Now, subject it to substitutions:
    #
	# Substitution is in x steps:
	# 1) \\ is substituted by \0 to be able to restore them later on
	# 2) The special construct \$( ... ) or $(...) is interpreted
	# 3) \char and \digits are interpreted
	# 4) \0 is restored to \
	#

	$temp=~ s/\\\\/\0/g; # save double backslash

	# Substitute program execution (for bash compatibility)
	$temp=~ s/\\\$\(/\$\(/g;
	while ($temp =~ m/^(.*)\$\(([^\)]+)\)(.*)$/) {
		my $sub='';
		my ($save1, $code, $save2) = ($1, $2, $3);
		eval {
			$sub=Psh::OS::backtick($code);
			chomp $sub;
		};
		$sub='' if( $@);
		$sub=~ s/\\/\0/g;
		$temp=$save1 . $sub . $save2;
	}

	# Standard prompt_var substitution
	$temp=~ s/\\([0-9]x?[0-9a-fA-F]*|[^0-9\\])/&prompt_helper($1)/ge;

	$temp=~ s/\0/\\/g; # restore former double backslash

	return $temp;
}

sub normal_prompt {
	my $prompt= $Psh::prompt;
	$prompt= $ENV{PS1} unless defined $prompt;
	$prompt= $default_prompt unless defined $prompt;
	return $prompt;
}

sub continue_prompt {
	my $prompt= $Psh::prompt_cont;
	$prompt= $ENV{PS2} unless defined $prompt;
	$prompt= '> ' unless defined $prompt;
	return $prompt;
}

sub pre_prompt_hook {
	change_title();
}

sub change_title {
	my $title= $ENV{PSH_TITLE};
	return if !$title;
	my $term= $ENV{TERM};
	if( $term=~ /^(rxvt.*)|(xterm.*)|(.*xterm)|(kterm)|(aixterm)|(dtterm)/) {
		print "\017\033]2;$title\007";
	}
}

1;
