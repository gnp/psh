#!/usr/local/bin/perl
#
#	Complete.pm : 
#
#	$Id$

package Psh::Builtins::Complete;

use Psh::PCompletion qw(pcomp_getopts %ACTION %COMPSPEC compgen redir_test);

=item * C<complete>

Define programmable completion method.

	complete [-abcdefjkvu] [-A ACTION] [-G GLOBPAT] [-W WORDLIST]
		 [-P PREFIX] [-S SUFFIX] [-X FILTERPAT] [-F FUNCTION]
		 [-C COMMAND] NAME [NAME] ..
	complete -pr [NAME ...]

=cut

sub usage_complete {
    print STDERR <<EOM;
complete [-abcdefjkvu] [-A ACTION] [-G GLOBPAT] [-W WORDLIST]
	 [-P PREFIX] [-S SUFFIX] [-X FILTERPAT] [-F FUNCTION]
	 [-C COMMAND] NAME [NAME] ..
complete -pr [NAME ...]
EOM
}

sub bi_complete {
    my $cs = pcomp_getopts($_[1]) or usage_complete, return;
    @_ = @{$_[1]};

    if (! $cs->{remove} && $#_ < 0) {
		# no option or only -p
		foreach (sort keys(%COMPSPEC)) {
			print_compspec($_);
		}
	} elsif ($cs->{print}) {
		foreach (@_) {
			print_compspec($_);
		}
    } elsif ($cs->{remove}) {
		@_ = keys %COMPSPEC if ($#_ < 0);
		foreach (@_) {
			delete $COMPSPEC{$_};
		}
    } else {
		foreach (@_) {
			$COMPSPEC{$_} = $cs;
		}
    }
}

sub print_compspec ($) {
    my ($cmd) = @_;
    my $cs = $COMPSPEC{$cmd};
    print 'complete';
    foreach (sort keys(%ACTION)) {
	print " -A $_" if ($cs->{action} & $ACTION{$_});
    }
    print " -G $cs->{globpat}"	if defined $cs->{globpat};
    print " -W $cs->{wordlist}"	if defined $cs->{wordlist};
    print " -C $cs->{command}"	if defined $cs->{command};
    print " -F $cs->{function}"	if defined $cs->{function};
    print " -X $cs->{filterpat}"	if defined $cs->{filterpat};
    print " -P $cs->{prefix}"	if defined $cs->{prefix};
    print " -S $cs->{suffix}"	if defined $cs->{suffix};
    print " $cmd\n";
}

sub cmpl_complete {
    my ($cur, $dummy, $start, $line) = @_;

    my ($prev) = $start =~ /(\S+)\s+$/;

    my @COMPREPLY = redir_test($cur, $prev);
    return @COMPREPLY if @COMPREPLY;

    if ($start =~ /^\s*(\S+)\s+$/ || $cur eq '-' ) {
        return qw(-a -b -c -d -e -f -j -k -v -u -r -p -A -G -W -P -S -X -F -C);;
    }

    if ($prev eq '-A') {
        return qw(alias arrayvar binding builtin command directory
                  disabled enabled export file function helptopic hostname
                  job keyword running setopt shopt signal stopped variable);
    } elsif ($prev eq '-F') {
        return compgen('-A', 'function', $cur);
#    } elsif ($prev eq '-C') {
#       return compgen('-c', $cur);
    } else {
        return compgen('-c', $cur);
    }
}

