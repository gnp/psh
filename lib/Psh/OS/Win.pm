package Psh::OS::Win;

use strict;
use vars qw($VERSION);
use Psh::Util ':all';

eval { use Win32; };

if ($@) {
	print_error_i18n('no_libwin32');
	die "\n";
}

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

#
# For documentation see Psh::OS::Unix
#

$Psh::OS::PATH_SEPARATOR=';';
$Psh::OS::FILE_SEPARATOR='\\';

# dummy currently
sub get_hostname { return 'localhost'; }

# TODO: locate hosts file on Windows and do the same as for Unix
# (it can be anywhere in PATH I think)
sub get_known_hosts { return (); }

sub exit {
	CORE::exit(@_[0]) if $_[0];
	CORE::exit(0);
}


#
# void display_pod(text)
#
sub display_pod {
	my $tmp= POSIX::tmpnam();
	my $text= shift;

	open( TMP,">$tmp");
	print TMP $text;
	close(TMP);

	eval {
		use Pod::Text;
		Pod::Text::pod2text($tmp,*STDOUT);
	};
	if( $@) {
		print $text;
	}

	1 while unlink($tmp); #Possibly pointless VMSism
}

sub reap_children {1};

sub execute_complex_command {
	my @array= @{shift()};
	my $fgflag= shift @array;
	my @return_val;
	my $pgrp_leader=0;
	my $pid;
	my $string='';
	my @tmp;

	if($#array) {
		print_error("No piping yet.\n");
		return ();
	}

	for( my $i=0; $i<@array; $i++) {
		my ($coderef, $how, $options, $words, $strat, $text)= @{$array[$i]};
		my $line= join(' ',@$words);
		my ($eval_thingie,@return_val)= &$coderef( \$line, $words,$how);
		my @tmp;
		
		if( defined($eval_thingie)) {
			@tmp= fork_process($eval_thingie,$fgflag,$text);
		}
		if( @return_val < 1 ||
			!defined($return_val[0])) {
			@return_val= @tmp;
		}
	}
	return @return_val;
}

sub fork_process {
	local( $Psh::code, $Psh::fgflag, $Psh::string) = @_;
	local $Psh::pid;

	print_error_i18n('no_jobcontrol') unless $Psh::fgflag;

	if( ref($Psh::code) eq 'CODE') {
		return &{$Psh::code};
	} else {
		system($Psh::code);
	}
}

sub has_job_control { return 0; }

sub get_all_users { return (); } # this should have a value on NT and Win9x with multiple profiles
sub restart_job {1}
sub remove_signal_handlers {1}
sub setup_signal_handlers {1}
sub setup_sigsegv_handler {1}
sub setup_readline_handler {1}
sub reinstall_resize_handler {1}

sub get_home_dir {
	my $user= shift;
	return $ENV{HOME} if( ! $user && $ENV{HOME} );
	return "\\";
} # we really should return something (profile?)

sub remove_readline_handler {1} #FIXME: better than not running at all

sub is_path_absolute {
	my $path= shift;

	return substr($path,0,1) eq "\\" ||
		$path=~ /^[a-zA-Z]\:\\/;
}

sub get_path_extension {
	my $extsep = $Psh::OS::PATH_SEPARATOR || ';';
	my $pathext = $ENV{PATHEXT} || ".cmd${extsep}.bat${extsep}.com${extsep}.exe";
	return split("$extsep",$pathext);
}

1;

__END__

=head1 NAME

Psh::OS::Win - Contains Windows specific code


=head1 SYNOPSIS

	use Psh::OS;

=head1 DESCRIPTION

An implementation of Psh::OS for Win32 systems. This module
requires libwin32.

=head1 AUTHOR

Markus Peter, warp@spin.de
Omer Shenker, oshenker@iname.com

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
