package Psh::OS;

use strict;
use vars qw($VERSION);

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

my $ospackage="Psh::OS::Unix";

$ospackage="Psh::OS::Mac" if( $^O eq "MacOS");
$ospackage="Psh::OS::Win" if( $^O eq "MSWin32");

sub AUTOLOAD {
	$AUTOLOAD=~ s/.*:://;
	my $name="$ospackage::$AUTOLOAD";
	die "Function `$AUTOLOAD' in Psh::OS does not exist." unless
		eval "exists ${ospackage}::\{$AUTOLOAD\}";
	*$AUTOLOAD=  &$name;
	goto &$AUTOLOAD;
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


