
use strict;

BEGIN {
	eval "use Test;";

	if( $@) {
		print STDERR "The Parser test module needs Test.pm\n";
		exit 0;
	}
	plan(tests => 2, todo=> [2]);
}

use Psh::Parser;

my ($string,@arr);

#
# First test. Test wether decompose handles " and '
#
$string="foo bar \"bla'bla\" 'bla\"bla";
@arr= Psh::Parser::decompose($string);

if( $arr[0] eq 'foo' &&
	$arr[1] eq 'bar' &&
	$arr[2] eq "\"bla'bla\"" &&
	$arr[3] eq "'bla\"bla")
{
	ok(1);
}
else
{
	ok(0);
}

#
# Second test - test wether decompose handles backticks
#
$string='`foo bar`';
@arr= Psh::Parser::decompose($string);

if( $#arr==0 &&
	$arr[0] eq '`foo bar`')
{
	ok(1);
}
else
{
	ok(0);
}

