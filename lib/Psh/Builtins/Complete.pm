#!/usr/local/bin/perl
#
#	Complete.pm : 
#
#	$Id$

package Psh::Builtins::Complete;

=item * C<complete module MODULE>

Load a pre-defined completion module

=item * C<complete module list>

Lists pre-defined completion modules

=item * C<complete ...>

Define programmable completion method.

	complete [-abcdefjkvu] [-A ACTION] [-G GLOBPAT] [-W WORDLIST]
		 [-P PREFIX] [-S SUFFIX] [-X FILTERPAT] [-x FILTERPAT]
		 [-F FUNCTION] [-C COMMAND] NAME [NAME] ..

=item * C<complete -p [NAME ...]>

Print completion spec for commands NAME

=item * C<complete -r NAME>

Delete completion spec for command NAME

=cut

sub bi_complete {
	my $cs;

	if ($_[1] and $_[1][0] and 
		$_[1][0] eq 'module' and
	    $_[1][1]) {
		my @dirs=
		  (
		   Psh::OS::catdir(Psh::OS::rootdir(),'usr','share',
							  'psh','complete'),
		   Psh::OS::catdir(Psh::OS::rootdir(),'usr','local','share',
							  'psh','complete'),
		   Psh::OS::catdir(Psh::OS::get_home_dir(),'.psh','share','complete'),
		   Psh::OS::catdir(Psh::OS::rootdir(),'psh','complete')
		  );
		if ($_[1][1] eq 'list') {
			my %result=();
			foreach my $dir (@dirs) {
				next unless -r $dir;
				my @tmp= Psh::OS::glob('*',$dir);
				foreach my $file (@tmp) {
					my $full= Psh::OS::catfile($dir,$file);
					next if !-r $full or -d _;
					next if $file=~/\~$/;
					$result{$file}=1;
				}
			}
			Psh::Util::print_list( sort keys %result);
			return (1,undef);
		} else {
			my $file=$_[1][1];
			my @lines;
			foreach my $dir (@dirs) {
				my $full= Psh::OS::catfile($dir,$file);
				if (-r $full and !-d $full) {
					$file= $full;
					last;
				}
			}

			open(THEME,"< $file");
			@lines= <THEME>;
			close(THEME);
			if (!@lines) {
				Psh::Util::print_error("Could not find completion module '$file'.\n");
				return (0,undef);
			}
			if ($lines[0]=~/^\#\!.*pshcomplete/) { # psh-script
				my $tmp= $lines[1];
				$tmp=~s/^\s*\#//;
				my @commands= split /\s+/, $tmp;
				require Psh::Completion;
				Psh::Completion::add_module(\@commands,$file);
				return (1,undef);
			} else {
				Psh::Util::print_error("Completion module '$file' is not in a valid format.\n");
				return (0,undef);
			}
		}
	}
	elsif (!$_[1]) {
		require Psh::Builtins::Help;
		Psh::Builtins::Help::bi_help('complete');
		return (0,undef);
	}

	require Psh::PCompletion;
	if (!($cs= Psh::PCompletion::pcomp_getopts($_[1]))) {
		require Psh::Builtins::Help;
		Psh::Builtins::Help::bi_help('complete');
		return (0,undef);
	}


    @_ = @{$_[1]};

    if (! $cs->{remove} && $#_ < 0) {
		# no option or only -p
		foreach (sort keys(%Psh::PCompletion::COMPSPEC)) {
			print_compspec($_);
		}
	} elsif ($cs->{print}) {
		foreach (@_) {
			print_compspec($_);
		}
    } elsif ($cs->{remove}) {
		@_ = keys %Psh::PCompletion::COMPSPEC if ($#_ < 0);
		foreach (@_) {
			delete $Psh::PCompletion::COMPSPEC{$_};
		}
    } else {
		foreach (@_) {
			$Psh::PCompletion::COMPSPEC{$_} = $cs;
		}
    }
	return (1,undef);
}

sub print_compspec ($) {
    my ($cmd) = @_;
	require Psh::PCompletion;

    my $cs = $Psh::PCompletion::COMPSPEC{$cmd};
    print 'complete';
    foreach (sort keys(%Psh::PCompletion::ACTION)) {
		print " -A $_" if ($cs->{action} & $Psh::PCompletion::ACTION{$_});
    }
    print " -G \'$cs->{globpat}\'"	if defined $cs->{globpat};
    print " -W \'$cs->{wordlist}\'"	if defined $cs->{wordlist};
    print " -C $cs->{command}"		if defined $cs->{command};
    print " -F $cs->{function}"		if defined $cs->{function};
    print " -X \'$cs->{filterpat}\'"	if defined $cs->{filterpat};
    print " -x \'$cs->{ffilterpat}\'"	if defined $cs->{ffilterpat};
    print " -P \'$cs->{prefix}\'"	if defined $cs->{prefix};
    print " -S \'$cs->{suffix}\'"	if defined $cs->{suffix};
	print " -o $cs->{option}" if defined $cs->{option};
    print " $cmd\n";
}

sub cmpl_complete {
    my ($cur, $dummy, $start, $line) = @_;

    my ($prev) = $start =~ /(\S+)\s+$/;

	require Psh::PCompletion;

    my @COMPREPLY = Psh::PCompletion::redir_test($cur, $prev);
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

1;

