package Psh::Builtins::Fc;

use strict;
require Psh;
require Psh::Util;
require Getopt::Std;

=item * C<fc> -s [OLD=NEW] [command]

The last command or the last command starting with
[command] is re-executed after OLD is subsituted with NEW.

=item * C<fc> -p prepend [command]

Prepends the text prepend in front of the last command or the
last command starting with [command] and re-execute it.

=item * C<fc> -l

Lists the last 15 commands, newest last

=item * C<fc> [-e editor] [range]

Edit the last command (or [range] commands) in either [editor],
C<$ENV{FCEDIT}>, C<$ENV{EDITOR}> or vi.

=cut

sub _locate_command {
	my $command=shift;
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
			Psh::Util::print_error_i18n('bi_fc_notfound');
			return undef;
		}
	}
	return $comnum;
}

sub bi_fc
{
	my $line= shift;
	local @ARGV = @{shift()};
	my $opt={};
	Getopt::Std::getopts('splre:',$opt);

	return (0,undef) unless $#Psh::history;
	if ($opt->{'l'}) {
		my $num=@Psh::history;
		$num=15 if $num>15;
		for (my $i=@Psh::history-$num; $i<@Psh::history; $i++) {
			Psh::Util::print_out(' '.sprintf('%3d',$i+1).'  '.$Psh::history[$i]."\n");
		}
	} elsif ($opt->{'s'}) {
		my $subst='';
		my $command='';
		while ($_=pop(@ARGV)) {
			if (/\=/) {
				$subst=$_;
				last;
			}
			$command.=$_;
		}
		my $comnum= _locate_command($command);
		return (0,undef) unless defined $comnum;
		my $comtext=$Psh::history[$comnum];
		if ($subst) {
			my ($old,$new)=$subst=~/^(.*?[^\\])\=(.*)$/;
			$comtext=~s/$old/$new/;
		}
		Psh::Util::print_out($comtext."\n");
		Psh::add_history($comtext);
		return Psh::evl($comtext);
	} elsif ($opt->{'p'}) {
		my $prepend= shift @ARGV;
		my $command= join ' ',@ARGV;
		my $comnum= _locate_command($command);
		return (0,undef) unless defined $comnum;
		my $comtext="$prepend $Psh::history[$comnum]";
		Psh::Util::print_out($comtext."\n");
		Psh::add_history($comtext);
		return Psh::evl($comtext);
	} else {
		if (!$Psh::interactive) {
			Psh::Util::print_error("fc: not running interactively - cancelled\n");
			return (0,undef);
		}
		my $file= Psh::OS::tmpnam();
		my $editor= Psh::OS::get_editor($opt->{e} || $ENV{FCEDIT});
		my $from=my $to=$#Psh::history;
		if ($ARGV[0]=~/^\s*(\d+)-(\d+)/) {
			($from,$to)=($1,$2);
		} elsif ($ARGV[0]=~/^\s*(\d+)\s*$/) {
			($from,$to)=($1,$1);
		}
		if ($from<0 or $to<0 or $from>$#Psh::history or
		    $to>$#Psh::history) {
			Psh::Util::print_error("fc: specified range not in history\n");
			return (0,undef);
		}

		if (open(FILE,"> $file")) {
			for (my $i=$from; $i<=$to; $i++) {
				print FILE $Psh::history[$i-1]."\n";
			}
			close(FILE);
		}
		system("$editor $file");
		Psh::process_file($file);
		eval {
			unlink($file);
		};
	}
	return (1,undef);
}



1;
