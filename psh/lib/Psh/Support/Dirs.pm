package Psh::Support::Dirs;

use vars qw(@stack $stack_pos);

use Psh::Util qw(:all print_list);
require Psh::OS;
require File::Spec;

@stack= ();
$stack_pos=0;

1;
