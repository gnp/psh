package Psh2::Builtins::Rename;

use strict;

require Psh2::Language::Perl;

=item * C<rename> [-i] perlcode [files]

"rename" provides the filename in $_ to perlcode
and renames according to the new value of $_ modified
by perlcode.

Originally written by Larry Wall

=cut


sub execute
{
    my ($psh, $words)= @_;
    my @words=@$words;
    shift @words;

    my $inspect=0;
    my $op= shift @words;
    if ($psh->{interactive} and $op and $op eq '-i') {
	$inspect=1;
	$op= shift @words;
    }

    if (!$op) {
	require Psh2::Builtins::Help;
	Psh2::Builtins::Help::execute($psh, ['help','rename']);
	return 0;
    }

    my $count=0;
    foreach my $file (@words) {
	unless (-e $file) {
	    $psh->printferrln($psh->gt('rename: %s: %s'),$file, $!);
	    next;
	}
	my $was= $file;
	$Psh2::Language::Perl::lastscalar=$was;
	Psh2::Language::Perl::protected_eval($op);
	my $now= $Psh2::Language::Perl::lastscalar;
	if ($was ne $now) {
	    if ($inspect and -e $now) {
		next unless $psh->fe->prompt('yn',
					     sprintf($psh->gt('rename: remove %s?'), $now)) eq 'y';
	    } elsif (-e $now) {
		$psh->printferrln($psh->gt('rename: %s exists. %s not renamed.'), $_, $was);
		next
	    }
	    if (CORE::rename($was,$now)) {
		$count++;
	    } else {
		$psh->printferrln($psh->gt(q[rename: cannot rename %s to %s: $!], $was, $now, $!));
	    }
	}
    }
    return $count>0;
}

1;
