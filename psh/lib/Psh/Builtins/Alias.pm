package Psh::Builtins::Alias;

require Psh::Support::Alias;
require Psh::Util;
require Psh::Parser;

=item * C<alias [NAME [=] REPLACEMENT]> 

Add C<I<NAME>> as a built-in so that NAME <REST_OF_LINE> will execute
exactly as if REPLACEMENT <REST_OF_LINE> had been entered. For
example, one can execute C<alias ls ls -F> to always supply the B<-F>
option to "ls". Note the built-in is defined to avoid recursion
here.

With no arguments, prints out a list of the current aliases.
With only the C<I<NAME>> argument, prints out a definition of the
alias with that name.

=cut

sub bi_alias
{
	my $line = shift;
	my ($command, $firstDelim, @rest) = Psh::Parser::decompose('([ \t\n=]+)', $line, undef, 0);
	my $text = join('',@rest); # reconstruct everything after the
	# first delimiter, sans quotes
	if (($command eq "") && ($text eq "")) {
		my $wereThereSome = 0;
		for $command (sort keys %Psh::Support::Alias::aliases) {
			my $aliasrhs = $Psh::Support::Alias::aliases{$command};
			$aliasrhs =~ s/\'/\\\'/g;
			Psh::Util::print_out("alias $command='$aliasrhs'\n");
			$wereThereSome = 1;
		}
		if (!$wereThereSome) {
			Psh::Util::print_out_i18n('bi_alias_none');
		}
	} elsif( $text eq '') {
		my $aliasrhs = $Psh::Support::Alias::aliases{$command};
		$aliasrhs =~ s/\'/\\\'/g;
		Psh::Util::print_out("alias $command='$aliasrhs'\n");
	} elsif ($text eq '-a') {
		Psh::Util::print_error_i18n('bi_alias_cant_a');
		return (0,undef);
	} else {
		$Psh::Support::Alias::aliases{$command} = $text;
	}
	return (1,undef);
}


1;
