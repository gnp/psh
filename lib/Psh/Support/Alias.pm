package Psh::Support::Alias;

use strict;
use vars qw(%aliases);

%aliases=();

#
# bool _is_aliased( string COMMAND )
#
# returns TRUE if COMMAND is aliased:

sub _is_aliased {
       my $command = shift;
       if (exists($aliases{$command})) { return 1; }
       return 0;
}

# Returns a list of aliases commands
sub get_alias_commands {
	return keys %aliases;
}

1;
