#!/usr/bin/perl

BEGIN {
    eval {
	require Test::More;
    };
    if ($@) {
	print "1..0 # Skipped: Test::More is not installed\n";
	exit(0);
    }
}

use Test::More 'no_plan';
use Data::Dumper;

use_ok 'Psh2::Parser';

sub test_decompose ($$) {
    my ($line, $expected)= @_;
    my @tmp= Psh2::Parser::decompose($line);
    ok(eq_array( $tmp[0], $expected), "decompose: $line") or
	diag(Dumper($tmp[0]));
	;
}

test_decompose 'ls', [ 'ls' ];
test_decompose 'ls foo', [ 'ls', ' ', 'foo'];
test_decompose 'ls|cat', [ 'ls', '|', 'cat'];
test_decompose 'ls |cat', [ 'ls', ' ', '|', 'cat' ];
test_decompose 'cat < file | echo', [ 'cat', ' ', '<', ' ', 'file', ' ',
				    '|', ' ', 'echo'];

test_decompose 'echo foo\\nbar', [ 'echo', ' ', "foo\nbar"];
test_decompose 'echo "foo bar"', [ 'echo', ' ', '"foo bar"'];
test_decompose 'echo foo\'bar',  [ 'echo', ' ', "foo'bar"];
test_decompose q[echo 'foo\\nbar'], [ 'echo', ' ', "'foo\\nbar'"];
test_decompose q[echo 'foo{bar'], [ 'echo', ' ', "'foo{bar'"];
test_decompose 'echo foo\\ bar', [ 'echo', ' ', 'foo bar'];
test_decompose 'echo foo\\.bar', [ 'echo', ' ', 'foo.bar'];
test_decompose 'echo foo\\\\bar', [ 'echo', ' ', 'foo\\bar'];
test_decompose 'foo ( bar )', [ 'foo',' ','( bar )'];

