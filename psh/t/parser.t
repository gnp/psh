
use strict;

BEGIN {
	eval "use Test;";

	if( $@) {
		print STDERR "The Parser test module needs Test.pm\n";
		exit 0;
	}
	use Psh;
	plan(tests => 2);
}

use Psh::Parser;

my ($string,@arr);

#
# First test. Test whether std_tokenize handles " and '
#
$string="foo \t  bar \"bla'bla\" 'bla\"bla";
@arr= Psh::Parser::std_tokenize($string);

if( $arr[0] eq 'foo' &&
	$arr[1] eq 'bar' &&
	$arr[2] eq "\"bla'bla\"" &&
	$arr[3] eq "'bla\"bla")
{
	ok(1);
}
else
{
	print STDERR "Unexpected pieces:", join('|',@arr), "\n";
	ok(0);
}

#
# Second test - test whether decompose handles backticks
#
# Note psh doesn't use these anywhere, but we'll have to add them to
# std_tokenize if we ever want to do "command expansion"
#
$string='`foo bar`';
my %quotes = qw(' ' " " ` `);

@arr= Psh::Parser::decompose(' ',$string,undef,1,\%quotes);

if( $#arr==0 &&
	$arr[0] eq '`foo bar`')
{
	ok(1);
}
else
{
	print STDERR "Unexpected pieces:", join('|',@arr), "\n";
	ok(0);
}

