package Psh::Builtins::Forfile;

=item * C<forfile globpattern command>

Comparable to the sh-for command:

for i in globpattern; do command $i; done

The current filename will be assigned to $_

Examples:

forfile *.zip unzip $_

=cut

require Psh::Parser;
require Psh;
require Psh::Util;

sub bi_forfile {
	my @words=@{$_[1]};
	my @files= Psh::OS::glob(Psh::Parser::unquote($words[0]));
	foreach my $file (@files) {
		$command= join(' ',@words[1..$#words]);
		Psh::evl("\$\_=\"$file\"; $command");
	}
	return (1,undef);
}

1;
