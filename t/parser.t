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
    my @tmp;
    eval { @tmp= Psh2::Parser::decompose({}, $line, {}); };
    if ($@) {
	fail() and diag("decompose: $line with error $@");
    } else {
	ok(eq_array( $tmp[0], $expected), "decompose: $line") or
	  diag("input: $line got: ".Dumper($tmp[0]));
	;
    }
}

test_decompose 'ls', [ 'ls' ];
test_decompose 'ls foo', [ 'ls', 'foo'];
test_decompose 'ls|cat', [ 'ls', [6], 'cat'];
test_decompose 'ls |cat', [ 'ls', [6], 'cat' ];
test_decompose 'cat < file | echo', [ 'cat', [10], 'file', [6], 'echo'];
test_decompose 'a [abc]', ['a','[abc]'];
test_decompose 'a [a\\b]', ['a', '[a\\b]'];
test_decompose 'a [a\\bc]', ['a', '[a\\bc]'];
test_decompose 'echo foo\\nbar', [ 'echo', "foo\\nbar"];
test_decompose 'echo "foo bar"', [ 'echo', 'foo bar'];
test_decompose q[echo 'foo\\nbar'], [ 'echo', "foo\\nbar"];
test_decompose q[echo 'foo{bar'], [ 'echo', "foo{bar"];
test_decompose 'echo foo\\ bar', [ 'echo', 'foo\\ bar'];
test_decompose 'foo=bar ls', [ 'foo=bar','ls'];
test_decompose 'foo ( bar )', [ 'foo','( bar )'];
test_decompose 'foo "" bar', [ 'foo','','bar'];
test_decompose 'foo  bar', [ 'foo', 'bar'];
test_decompose q[foo 'foo''bar'], [ 'foo', "foo'bar"];
test_decompose q[foo { a { b } c} {d}], ['foo','{ a { b } c}','{d}'];
test_decompose qq[foo\nbar], [ 'foo', [4], 'bar'];
test_decompose qq[foo { a \n bc \n bar } bla], [ 'foo', "{ a \n bc \n bar }",'bla'];
test_decompose 'foo bar;', [ 'foo', 'bar', [3]];
test_decompose 'foo;', [ 'foo', [3]];
test_decompose "foo\n", [ 'foo', [4]];
