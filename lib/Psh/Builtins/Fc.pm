package Psh::Builtins::Fc;

use strict;
use Psh::Util qw(:all starts_with);
use Getopt::Std;

=item * C<fc> -s [OLD=NEW] [command]

The last command or the last command starting with
[command] is re-executed after OLD is subsituted with NEW.

=item * C<fc> -l

Lists the last 15 commands, newest last

=item * C<fc> [-e editor] [range]

Edit the last command (or [range] commands) in either [editor],
C<$ENV{FCEDIT}>, C<$ENV{EDITOR} or vi.

=cut


sub bi_fc
{
	my $line= shift;
	local @ARGV = @{shift()};
	my $opt={};
	getopts('slre:',$opt);

	if ($opt->{'l'}) {
		my $num=@Psh::history;
		$num=15 if $num>15;
		for (my $i=@Psh::history-$num; $i<@Psh::history; $i++) {
			print_out(' '.sprintf('%3d',$i+1).'  '.$Psh::history[$i]."\n");
		}
	} elsif ($opt->{'s'}) {
		my $command='';
		my $subst='';
		while ($_=pop(@ARGV)) {
			if (/\=/) {
				$subst=$_;
				last;
			}
			$command.=$_;
		}
		my $comnum=$#Psh::history-1; # (otherwise we find the fc)
		if ($command) {
			my $found;
			for (my $i=$comnum; $i>=0; $i--) {
				if (starts_with($Psh::history[$i],$command)) {
					$comnum=$i;
					$found=1;
					last;
				}
			}
			unless ($found) {
				print_error_i18n('bi_fc_notfound');
				return undef;
			}
		}
		my $comtext=$Psh::history[$comnum];
		if ($subst) {
			my ($old,$new)=$subst=~/^(.*?[^\\])\=(.*)$/;
			$comtext=~s/$old/$new/;
		}
		print_out($comtext."\n");
		Psh::evl($comtext);
	} else {
		my $file= Psh::OS::tmpnam();
		my $editor= $opt->{e}||$ENV{FCEDIT}||$ENV{EDITOR}||'vi';
		my $fh= new FileHandle("> $file");
		my $from=my $to=$#Psh::history;
		($from,$to)=$ARGV[0]=~/(\d+)-(\d+)/ if $ARGV[0]=~/-/;
		for (my $i=$from; $i<=$to; $i++) {
			print $fh $Psh::history[$i-1]."\n";
		}
		$fh->close();
		system("$editor $file");
		Psh::process_file($file);
	}
	return undef;
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

