package Psh::Support::Alias;

use strict;

$Psh::Support::Alias::loaded=1;

%Psh::Support::Alias::aliases=();

#
# bool _is_aliased( string COMMAND )
#
# returns TRUE if COMMAND is aliased:

sub is_aliased {
       my $command = shift;
       if (exists($Psh::Support::Alias::aliases{$command})) { return 1; }
       return 0;
}

#backwards compatibility
sub _is_aliases {
	return is_aliases(@_);
}

# Returns a list of aliases commands
sub get_alias_commands {
	return keys %Psh::Support::Alias::aliases;
}

1;
