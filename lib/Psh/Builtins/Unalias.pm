package Psh::Builtins::Unalias;

require Psh::Util;
require Psh::Support::Alias;

=item * C<unalias NAME | -a | all]>

Removes the alias with name <C<I<NAME>> or all aliases if either <C<I<-a>>
(for bash compatibility) or <C<I<all>> is specified.

=cut

sub bi_unalias {
	my $name= shift;
	if( ($name eq '-a' || $name eq 'all') and !Psh::Support::Alias::is_aliased($name) ) {
		%Psh::Support::Alias::aliases=();
		return (1,undef);
	} elsif( Psh::Support::Alias::is_aliased($name)) {
		delete($Psh::Support::Alias::aliases{$name});
		return (1,undef);
	} else {
		Psh::Util::print_error_i18n('unalias_noalias', $name);
		return (0,undef);
	}
	return (0,undef);
}


sub cmpl_unalias {
	my $text= shift;
	return (1,grep { Psh::Util::starts_with($_,$text) } Psh::Support::Alias::get_alias_commands());
}

1;
