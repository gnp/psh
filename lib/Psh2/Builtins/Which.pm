package Psh2::Builtins::Which;

require Getopt::Std;

=item * C<which command>

Locates the command in the filesystem.

=item * C<which -m module>

Locates the perl module in the filesystem

=item * C<which -r regexp>

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
package Psh2::_version;
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

sub execute
{
    my ($psh, $words)= @_;
    shift @$words;

    local @ARGV = @$words;

    my $opt={};
    Getopt::Std::getopts('aprmv',$opt);
    my $rest= join(' ',@ARGV);

    if ($opt->{'m'}) { # perl module search
        my $fs= $psh->file_separator();
        $rest=~ s/::/$fs/g;
        my $foundsth=0;
        foreach my $dir (@INC) {
            next unless $dir;
            my $file= $psh->catfile($dir,$rest.'.pm');
            if (-r $file) {
                $psh->print($file);
                if ($opt->{v}) {
                    my $version= parse_version($file);
                    $psh->print(" $version");
                }
                $psh->print("\n");
                $foundsth=1;
                last unless $opt->{a};
            }
        }
        return 1 if $foundsth;
    } else {
        if ($opt->{'r'}) {
            my $foundsth=0;
            my $path= $psh->recalc_absed_path();
            foreach my $dir (@$path) {
                next unless $dir;
                opendir(DIR, $dir);
                while (my $tmp= readdir(DIR)) {
                    next unless $tmp=~/$rest/;
                    $tmp= $psh->catfile($dir,$tmp);
                    next unless -f $tmp;
                    next unless -x _;
                    $psh->print("$tmp\n");
                    $foundsth=1;
                    last unless $opt->{a};
                }
                closedir(DIR);
                last if $foundsth and !$opt->{a};
            }
            return 1 if $foundsth;
        } else {
            if ($rest) {
                my @tmp=();
                push @tmp, grep { defined $_ } $psh->which($rest,$opt->{'a'}?1:0);
                foreach (@tmp) {
                    $psh->print("$_\n");
                }
                return 1 if @tmp;
            }
        }
    }
    return 0;
}

1;
