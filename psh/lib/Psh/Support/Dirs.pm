package Psh::Support::Dirs;

use vars qw(@stack $stack_pos);

use Psh::Util qw(:all print_list);
require Psh::OS;
require File::Spec;
require Psh::Completion;

my $PS=$Psh::OS::PATH_SEPARATOR;

@stack= ();
$stack_pos=0;

1;
