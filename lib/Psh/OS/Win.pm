package Psh::OS::Win;

use strict;
require Psh::Util;

eval {
	use Win32;
	use Win32::TieRegistry 0.20;
	use Win32::Process;
	use Win32::Console;
	use Win32::NetAdmin;
};

if ($@) {
	Psh::Util::print_error_i18n('no_libwin32');
	die "\n";
}

my $console= new Win32::Console();
my @user_cache=();

#
# For documentation see Psh::OS::Unix
#

$Psh::OS::PATH_SEPARATOR=';';
$Psh::OS::FILE_SEPARATOR='\\';

$Psh::history_file = "psh_history";

sub set_window_title {
	my $title=shift;
	$console->Title($title);
}


sub reinstall_resize_handler {
	# actually we have no 'handlers' here but instead simply do it
	my ($cols,$rows)=$console->Size();
	$ENV{COLUMNS}=$cols;
	$ENV{ROWS}=$rows;
}

sub get_hostname {
	my $name_from_reg = $Registry->{"HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\ComputerName\\ComputerName\\ComputerName"};
	return $name_from_reg if $name_from_reg;
	return 'localhost';
}

sub get_known_hosts {
	my $hosts_file = "$ENV{windir}\\HOSTS";
	if (open(F_KNOWNHOST,"< $hosts_file")) {
		my $hosts_text = join('', <F_KNOWNHOST>);
		close(F_KNOWNHOST);
		return Psh::Util::parse_hosts_file($hosts_text);
	} else {
		return ("localhost");
	}
}

#
# void display_pod(text)
#
sub display_pod {
	my $tmp= Psh::OS::tmpnam();
	my $text= shift;

	open( TMP,">$tmp");
	print TMP $text;
	close(TMP);

	eval {
		require Pod::Text;
		Pod::Text::pod2text($tmp,*STDOUT);
	};
	print $text if $@;

	unlink($tmp);
}

sub inc_shlvl {
	if (! $ENV{SHLVL}) {
		$Psh::login_shell = 1;
		$ENV{SHLVL} = 1;
	} else {
		$Psh::login_shell = 0;
		$ENV{SHLVL}++;
	}
}

sub execute_complex_command {
	my @array= @{shift()};
	my $fgflag= shift @array;
	my @return_val;
	my $pgrp_leader=0;
	my $success= 0;
	my $pid;
	my $string='';
	my @tmp;

	if($#array) {
		Psh::Util::print_error("No piping yet.\n");
		return ();
	}

	my $obj;
	for( my $i=0; $i<@array; $i++) {
		my ($strategy, $how, $options, $words, $text, $opt)= @{$array[$i]};
		local $Psh::current_options=$opt;
		my $line= join(' ',@$words);
		my ($eval_thingie,$bgflag);
		($success,$eval_thingie,$words,$bgflag,@return_val)= $strategy->execute( \$line, $words, $how, 0);

		my @tmp;

		if( defined($eval_thingie)) {
			($obj,$success,@tmp)= _fork_process($eval_thingie,$fgflag,$text,undef,$words);
		}
		if( @return_val < 1 ||
			!defined($return_val[0])) {
			@return_val= @tmp;
		}
		$string=$text;
	}
	if ($obj) {
		my $pid=$obj->GetProcessID();
		my $job=Psh::Joblist::create_job($pid,$string,$obj);
		if( $fgflag) {
			_wait_for_system($obj, 1);
		} else {
			my $visindex= Psh::Joblist::get_job_number($pid);
			Psh::Util::print_out("[$visindex] Background $pid $string\n");
		}
	}
	return ($success,@return_val);
}

sub _fork_process {
	local( $Psh::code, $Psh::fgflag, $Psh::string, $Psh::options,
		   $Psh::words) = @_;
	local $Psh::pid;

	# TODO: perhaps we should use Win32::Process?
	# hmm - won't help alot :-( - warp
	# print_error_i18n('no_jobcontrol') unless $Psh::fgflag;

	if( ref($Psh::code) eq 'CODE') {
		return (0,&{$Psh::code});
	} else {
		if ($Psh::words) {
			my $obj;
			Win32::Process::Create($obj,
								   @$Psh::words->[0],
								   $Psh::string,
								   0,
								   NORMAL_PRIORITY_CLASS,
								   ".");
			return ($obj,0);
			# We are passing around objects instead of pid because
			# Win32::Process currently only allows me to create objects,
			# not look them up via pid
		} else {
			return (0,system($Psh::code));
		}
	}
}

sub _wait_for_system {
	my ($obj, $quiet)=@_;

	return unless $obj;
	$obj->Wait(INFINITE);
	_handle_wait_status($obj,$quiet)
}

sub _handle_wait_status {
	my ($obj,$quiet)=@_;

	return '' unless $obj;
	my $pid= $obj->GetProcessID();
	my $job= Psh::Joblist::get_job($obj->GetProcessID());
	my $command = $job->{call};
	my $visindex= Psh::Joblist::get_job_number($pid);
	my $verb='';

	my $tmp= Psh::Locale::get_text('done');
	Psh::Util::print_out("[$visindex] \u$tmp $pid $command\n") unless $quiet;
	Psh::Joblist::delete_job($pid);
	return '';
}

sub fork_process {
	_fork_process(@_);
	return undef;
}

sub get_all_users {
	unless (@user_cache) {
		Win32::NetAdmin::GetUsers("",FILTER_NORMAL_ACCOUNT,\@user_cache);
	}
	return @user_cache;
}


sub has_job_control { return 1; }

sub resume_job {
	my $job= shift;
	$job->{assoc_obj}->Resume();
}

#
# void restart_job(bool FOREGROUND, int JOB_INDEX)
#
sub restart_job
{
	my ($fg_flag, $job_to_start) = @_;

	my $job= Psh::Joblist::find_job($job_to_start);

	if(defined($job)) {
		my $pid = $job->{pid};
		my $command = $job->{call};

		if ($command) {
			my $tmp=Psh::Locale::get_text('restart');
			my $verb = "\u$tmp";
			my $qRunning = $job->{running};
			if ($fg_flag) {
				my $tmp= Psh::Locale::get_text('foreground');
				$verb = "\u$tmp";
			} elsif ($qRunning) {
			  # bg request, and it's already running:
			  return;
			}
			my $visindex = Psh::Joblist::get_job_number($pid);
			Psh::Util::print_out("[$visindex] $verb $pid $command\n");

			if($fg_flag) {
				eval { _wait_for_system($job->{assoc_obj}, 0); };
			} elsif( !$qRunning) {
				$job->continue;
			}
		}
	}
}

sub get_home_dir {
	my $user= shift;
	my $home;
	if (!$user) {
		$home=$ENV{HOME}||$ENV{USERPROFILE}||$ENV{HOMEDRIVE}.$ENV{HOMEPATH};
	} else {
		# There is a UserGetAttributes function in Win32::NetAdmin but
		# it will only work if you're admin
		# I'v searched my registry but did not find something usable
	}
	return $home||"\\";
} # we really should return something (profile?)


sub get_rc_files {
	my @rc=();

	push @rc, "\\etc\\pshrc" if -r "\\etc\\pshrc";
	push @rc, "$ENV{WINDIR}\\pshrc" if -r "$ENV{WINDIR}\\pshrc";
	my $home= Psh::OS::get_home_dir();
	if ($home) { push @rc, catfile($home,'pshrc') };
	return @rc;
}

sub remove_readline_handler {1}

sub is_path_absolute {
	my $path= shift;

	return substr($path,0,1) eq "\\" ||
		$path=~ /^[a-zA-Z]\:\\/;
}

sub get_path_extension {
	my $extsep = $Psh::OS::PATH_SEPARATOR || ';';
	my $pathext = $ENV{PATHEXT} || $Registry->{"HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Session Manager\\Environment\\PATHEXT"} || ".cmd;.bat;.exe;.com"; # Environment has precedence over LOCAL_MACHINE registry
	return split("$extsep",$pathext);
}


# Simply doing backtick eval - mainly for Prompt evaluation
sub backtick {
	return `@_`;
}

sub abs_path {
	my $dir= shift;
	if (defined &Win32::GetFullPathName) {
		my $tmp= Win32::GetFullPathName($dir);
		$tmp=~tr:\\:/:; # otherwise prompt code etc messes up
		return $tmp;
	}
	undef;
}

sub getcwd_psh {
	my $tmp;
	if (defined &Win32::GetCwd) {
		$tmp= Win32::GetCwd();
		$tmp=~tr:\\:/:;
	}
	return $tmp||Psh::OS::fb_getcwd();
}


sub get_editor {
	my $suggestion= shift;
    return $suggestion||$ENV{VISUAL}||$ENV{EDITOR}||'edit';
}


# From File::Spec


sub canonpath {
    my ($path) = @_;
    $path =~ s/^([a-z]:)/\u$1/s;
    $path =~ s|/|\\|g;
    $path =~ s|([^\\])\\+|$1\\|g;                  # xx////xx  -> xx/xx
    $path =~ s|(\\\.)+\\|\\|g;                     # xx/././xx -> xx/xx
    $path =~ s|^(\.\\)+||s unless $path eq ".\\";  # ./xx      -> xx
    $path =~ s|\\\Z(?!\n)||
	  unless $path =~ m#^([A-Z]:)?\\\Z(?!\n)#s;   # xx/       -> xx    return $path;
}

sub catfile {
    my $file = pop @_;
    return $file unless @_;
    my $dir = catdir(@_);
    $dir .= "\\" unless substr($dir,-1) eq "\\";
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
    return scalar($file =~ m{^([a-z]:)?[\\/]}is);
}

sub rootdir {
	"\\";
}

sub splitdir {
    my ($directories) = @_ ;

    if ( $directories !~ m|[\\/]\Z(?!\n)| ) {
        return split( m|[\\/]|, $directories );
    }
    else {
        my( @directories )= split( m|[\\/]|, "${directories}dummy" ) ;
        $directories[ $#directories ]= '' ;
        return @directories ;
    }
}

sub splitpath {
    my ($path, $nofile) = @_;
    my ($volume,$directory,$file) = ('','','');
    if ( $nofile ) {
        $path =~
            m{^( (?:[a-zA-Z]:|(?:\\\\|//)[^\\/]+[\\/][^\\/]+)? )
                 (.*)
             }xs;
        $volume    = $1;
        $directory = $2;
    }
    else {
        $path =~
            m{^ ( (?: [a-zA-Z]: |
                      (?:\\\\|//)[^\\/]+[\\/][^\\/]+
                  )?
                )
                ( (?:.*[\\\\/](?:\.\.?\Z(?!\n))?)? )
                (.*)
             }xs;
        $volume    = $1;
        $directory = $2;
        $file      = $3;
    }
 
    return ($volume,$directory,$file);
}
sub rel2abs {
    my ($path,$base ) = @_;

    if ( ! file_name_is_absolute( $path ) ) {
        if ( !defined( $base ) || $base eq '' ) {
            $base = Psh::OS::getcwd_psh() ;
        }
        elsif ( ! file_name_is_absolute( $base ) ) {
            $base = rel2abs( $base ) ;
        }
        else {
            $base = canonpath( $base ) ;
        }
 
        my ( $path_directories, $path_file ) =
            (splitpath( $path, 1 ))[1,2] ;
 
        my ( $base_volume, $base_directories ) =
		  splitpath( $base, 1 ) ;
 
        $path = catpath(
						$base_volume,
						catdir( $base_directories, $path_directories ),
						$path_file
					   ) ;
    }
 
    return canonpath( $path ) ;
}

1;

__END__

=head1 NAME

Psh::OS::Win - Contains Windows specific code


=head1 SYNOPSIS

	use Psh::OS::Win32;

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
