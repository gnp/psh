package Psh::Builtins::Rename;
use strict;

use Psh::Util ':all';

=item * C<rename> [-i] perlcode [files]

"rename" provides the filename in $_ to perlcode
and renames according to the new value of $_ modified
by perlcode.

Originally written by Larry Wall

=cut


sub bi_rename
{
	my ($line, $words)= @_;
	my @words=@$words;
	my $inspect=0;
	my $op= shift @words;
	if ($Psh::interactive && $op eq '-i') {
		$inspect=1;
		$op= shift @words;
	}
	$op= Psh::Parser::unquote($op);
	@words = Psh::Parser::glob_expansion(\@words);
	@words = map { Psh::Parser::unquote($_)} @words;
	my $count=0;
	foreach my $file (@words) {
		unless (-e $file) {
			print STDERR "$Psh::bin: $file: $!\n";
			next;
		}
		my $was= $file;
		$Psh::PerlEval::lastscalar=$was;
		Psh::PerlEval::protected_eval($op);
		my $now= $Psh::PerlEval::lastscalar;
		if ($was ne $now) {
			if ($inspect && -e $now) {
				next unless Psh::Util::prompt("yn","remove $now?") eq 'y';
			} elsif (-e $now) {
				print STDERR "$_ exists. $was not renamed\n";
				next
			}
			if (CORE::rename($was,$now)) {
				$count++;
			} else {
				print STDERR "$Psh::bin: can't rename $was to $now: $!\n";
			}
		}
	}
	return ($count>0,$count);
}



1;

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

