package Psh::OS::Mac;

use strict;
use vars qw($VERSION);

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

#
# I just looked at MacPerl and currently doubt that a port of
# psh with sensible functionality is possible at all
# -warp (Markus Peter)

sub AUTOLOAD {
	die "Sorry, no Mac support available.\n";
}

1;

__END__

=head1 NAME

Psh::OS::Mac - Contains Mac specific code


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


