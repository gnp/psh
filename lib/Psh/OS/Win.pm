package Psh::OS::Win;

use strict;
use vars qw($VERSION);
use Psh::Util ':all';

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

#
# For documentation see Psh::OS::Unix
#

# dummy currently
sub get_hostname { return 'localhost'; }

sub exit { CORE::exit( shift); }

# not necessary I think on Win32
sub reap_children {};

sub fork_process {
	local( $Psh::code, $Psh::fgflag, $Psh::string) = @_;
	local $Psh::pid;

	print_error_i18n('no_jobcontrol') unless $fgflag;

	if( ref($Psh::code) eq 'CODE') {
		&{$Psh::code};
	} else {
		system($Psh::code);
	}
}

sub has_job_control { return 0; }


sub glob {
	my @result= glob(shift);
	return @result;
}

sub get_all_users { return (); }
sub restart_job { }
sub remove_signal_handlers {}
sub setup_signal_handlers {}
sub setup_sigsegv_handler {}
sub setup_readline_handler {}

1;

__END__

=head1 NAME

Psh::OS::Win - Contains Windows specific code


=head1 SYNOPSIS

	use Psh::OS;

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


