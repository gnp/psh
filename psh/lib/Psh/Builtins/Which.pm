package Psh::Builtins::Which;

require Psh::Util;
require Getopt::Std;

=item * C<which command>

Locates the command in the filesystem.

=item * C<which -m module>

Locates the perl module in the filesystem

=item * C<which -r module>

Locates a command using a Perl regexp

Option C<-a> may be used to see more than one match.
Option C<-v> switches to a more verbose output.

=cut

sub parse_version
{
	my $file= shift;
	open(FILE,"< $file");
	my $inpod=0;
	my $result;
	while (<FILE>) {
		chomp;
		$inpod = /^=(?!cut)/ ? 1: /^=cut/ ? 0 : $inpod;
		next if $inpod;
		next unless /([\$*])(([\w\:\']*)\bVERSION)\b.*\=/;
		my $eval= qq{
package Psh::_version;
no strict;

local $1$2;
\$$2=undef; do {
    $_
}; \$$2
};
		no warnings;
		$result= eval($eval);
		last;
	}
	close(FILE);
	$result = 'undef' unless defined $result;
	return $result;
}

sub bi_which
{
	my $line= shift;
	local @ARGV = @{shift()};
	my $opt={};
	Getopt::Std::getopts('aprmv',$opt);
	my $rest= join(' ',@ARGV);

	if ($opt->{'m'}) { # perl module search
        $rest=~ s/::/$Psh::OS::FILE_SEPARATOR/g;
		my $foundsth=0;
        foreach my $dir (@Psh::origINC) {
			next unless $dir;
            my $file= Psh::OS::catfile($dir,$rest.'.pm');
            if (-r $file) {
				Psh::Util::print_out($file);
                if ($opt->{v}) {
		            my $version= parse_version($file);
					Psh::Util::print_out(" $version");
				}
		        Psh::Util::print_out("\n");
				$foundsth=1;
		        last unless $opt->{a};
            }
        }
		return (1,undef) if $foundsth;
	} else {
		if ($opt->{'r'}) {
			my $foundsth=0;
			Psh::Util::recalc_absed_path();
			foreach my $dir (@Psh::absed_path) {
				next unless $dir;
				opendir(DIR, $dir);
				while (my $tmp= readdir(DIR)) {
					next unless $tmp=~/$rest/;
					$tmp= Psh::OS::catfile($dir,$tmp);
					next unless -f $tmp;
					next unless -x _;
					Psh::Util::print_out("$tmp\n");
					$foundsth=1;
					last unless $opt->{a};
				}
				closedir(DIR);
				last if $foundsth and !$opt->{a};
			}
			return (1,undef) if $foundsth;
		} else {
			if ($rest) {
				my @tmp=();
				push @tmp, Psh::Util::which($rest,$opt->{'a'}?1:0);
				foreach (@tmp) {
					Psh::Util::print_out("$_\n");
				}
				return (1,undef) if @tmp;
			}
		}
	}
	return (0,undef);
}

1;
