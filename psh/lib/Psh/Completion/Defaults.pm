package Psh::Completion::Defaults;

use strict;

use vars qw($VERSION);

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

my $t=\%Psh::Completion::custom_completions;

$t->{find}=[' ',['-daystart','-depth','-follow',
				 '-help','-mount','-cnewer','-ctime',
				 '-gid','-name','-iname','-newer','-path',
				 '-regex','-type','-exec','-print']];






1;


__END__

=head1 NAME

Psh::Completion::Defaults - Sensible extended completion defaults

=head1 SYNOPSIS

	use Psh::Completion::Defaults;

=head1 DESCRIPTION

Add the above use statement to your .pshrc file to get some useful
defaults.

=cut

# Local Variables:
# mode:perl
# tab-width:4
# indent-tabs-mode:t
# c-basic-offset:4
# perl-label-offset:0
# perl-indent-level:4
# cperl-indent-level:4
# cperl-label-offset:0
# End:
