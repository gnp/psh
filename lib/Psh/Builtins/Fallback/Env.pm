package Psh::Builtins::Fallback::Env;

#
# void env
#
# Prints out the current environment if no 'env' command is on
# the system
#

sub bi_env
{
	foreach my $key (keys %ENV) {
		print_out("$key=$ENV{$key}\n");
	}
	return undef;
}
