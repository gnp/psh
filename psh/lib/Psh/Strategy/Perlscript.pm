package Psh::Strategy::Perlscript;

require Psh::Util;
require Config;

=item * C<perlscript>

If (1) the first word of the input line matches the
name of a file found in one of the directories listed
in the path ($ENV{PATH}), and (2) that file starts
with #!/.../perl, and (3) that perl is the same as the
Perl under which psh is running, psh will fork and run
the script using the already-loaded Perl interpreter.
The idea is to save the exec half of the fork-exec
that the executable strategy would do; typically the
exec is more expensive. Right now this strategy can
only handle the -w command-line switch on the #! line.
Note this strategy only makes sense before the
"executable" strategy; if it came after, it could
never trigger.

=cut

#
# bool matches_perl_binary(string FILENAME)
#
# Returns true if FILENAME referes directly or indirectly to the
# current perl executable
#

sub matches_perl_binary
{
	my ($filename) = @_;

	#
	# Chase down symbolic links, but don't crash on systems that don't
	# have them:
	#

	if ($Config::Config{d_readlink}) {
		my $newfile;
		while ($newfile = readlink($filename)) { $filename = $newfile; }
	}

	if ($filename eq $Config::Config{perlpath}) { return 1; }

	my ($perldev,$perlino) = (stat($Config::Config{perlpath}))[0,1];
	my ($dev,$ino) = (stat($filename))[0,1];

	#
	# TODO: Does the following work on non-Unix OS ?
	#

	if ($perldev == $dev and $perlino == $ino) { return 1; }

	return 0;
}

$Psh::strategy_which{perlscript}=
	sub {
		my $script = Psh::Util::which(${$_[1]}[0]);

		if (defined($script) and -r $script) {
			#
			# let's see if it really looks like a perl script
			#
			my $firstline;
			if (open(FILE,"< $script")) {
				$firstline= <FILE>;
				close(FILE);
			}
			else {
				return;
			}
			chomp $firstline;

			my $filename;
			my $switches;

			if (($filename,$switches) =
				($firstline =~ m|^\#!\s*(/.*perl)(\s+.+)?$|go)
				and matches_perl_binary($filename)) {
				my $possibleMatch = $script;
				my %bangLineOptions = ();

				if( $switches) {
					$switches=~ s/^\s+//go;
					local @ARGV = split(' ', $switches);

					#
					# All perl command-line options that take aruments as of
					# Perl 5.00503:
					#

					getopt('DeiFlimMx', \%bangLineOptions);
				}

				if ($bangLineOptions{w}) {
					$possibleMatch .= " warnings";
					delete $bangLineOptions{w};
				}

				#
				# TODO: We could handle more options. [There are some we
				# can't. -d, -n and -p are popular ones that would be tough.]
				#

				if (scalar(keys %bangLineOptions) > 0) {
					print_debug("[[perlscript: skip $script, options $switches.]]\n");
					return '';
				}

				return $possibleMatch;
			}
		}

		return '';
};


$Psh::strategy_eval{perlscript} = sub {
		my ($script, @options) = split(' ',$_[2]);
		my @arglist = @{$_[1]};

		shift @arglist; # Get rid of script name
		my $fgflag = 1;

		if (scalar(@arglist) > 0) {
			my $lastarg = pop @arglist;

			if ($lastarg =~ m/\&$/) {
				$fgflag = 0;
				$lastarg =~ s/\&$//;
			}

			if ($lastarg) { push @arglist, $lastarg; }
		}

		print_debug("[[perlscript $script, options @options, args @arglist.]]\n");

		my $pid;

		my %opts = ();
		foreach (@options) { $opts{$_} = 1; }


		return (sub {
			package main;
			# TODO: Is it possible/desirable to put main in the pristine
			# state that it typically is in when a script starts up,
			# i.e. undefine all routines and variables that the user has set?

			local @ARGV = @arglist;
			local $^W;

			if ($opts{warnings}) { $^W = 1; }
			else                 { $^W = 0; }

			do $script;

			CORE::exit 0;
		}, [], 1, undef);
};

@always_insert_before= qw( executable);

1;
