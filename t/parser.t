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

sub test_recombine ($$) {
    my ($line, $expected)= @_;
    my @tmp= Psh2::Parser::decompose($line);
    @tmp= @{Psh2::Parser::recombine_parts($tmp[0])};
    ok(eq_array( \@tmp, $expected), "recombine: $line") or
	diag(Dumper(\@tmp));
	;
}

sub test_recombine_fail ($$) {
    my ($line, $expected)= @_;
    my @tmp= Psh2::Parser::decompose($line);
    eval {
	Psh2::Parser::recombine_parts($tmp[0]);
    };
    if ($@) {
	like( $@, qr/^\Q$expected\E/, "recombine fail: $line");
    } else {
	fail("recombine did not catch error: $line");
    }
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

test_recombine '( foo { bar })', [ '( foo { bar })'];
test_recombine 'abc ( def [])', [ 'abc', ' ', '( def [])'];
test_recombine 'a >[1=3] b', ['a', ' ', '>', '[1=3]', ' ', 'b'];
test_recombine 'a > [1=3] b', ['a', ' ', '>', ' ','[1=3]', ' ', 'b'];
test_recombine_fail 'abc ( foo', 'parse: nest: open (';
test_recombine_fail '( { )', "parse: nest: wrong { )";

