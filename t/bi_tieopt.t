#!/usr/bin/perl

use strict;
use vars qw($scalar_opt $surprise_scalar_opt %hash_opt @array_opt);

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

use_ok 'Psh::OS';
use_ok 'Psh::Builtins::Tieopt';
use_ok 'Psh::Options';


# test cases:

$scalar_opt    = 'scalartest';
@array_opt     = ('arraytest1', 'arraytest2');
%hash_opt      = (
    'hashkey1' => 1,
    'hashkey2' => 2,
);

# tieopt name

Psh::Options::set_option('scalar_opt', '1bar');
Psh::Builtins::Tieopt::bi_tieopt('', [ 'scalar_opt' ]);
is($scalar_opt, '1bar', 'tieopt name - scalar - initial retrieve');

$scalar_opt = '1wubba';
is(Psh::Options::get_option('scalar_opt'), '1wubba', 'tieopt name - scalar - retrieve');

Psh::Options::set_option('scalar_opt', '1bam');
is($scalar_opt, '1bam', 'tieopt name - scalar - set');

Psh::Builtins::Tieopt::bi_tieopt('', [ '-u', 'scalar_opt' ]);
$scalar_opt = 'nothing interesting';
is(scalar Psh::Options::get_option('scalar_opt'), '1bam', 'tieopt name - scalar - untie');

# tieopt name

Psh::Builtins::Tieopt::bi_tieopt('', [ 'surprise_scalar_opt' ]);
$surprise_scalar_opt = 'a surprise';
is(Psh::Options::get_option('surprise_scalar_opt'), 'a surprise', 'tieopt name - scalar (implied) - retrieve');


Psh::Builtins::Tieopt::bi_tieopt('', [ '-u', 'scalar_opt' ]);
$scalar_opt = 'nothing interesting';
is(scalar Psh::Options::get_option('scalar_opt'), '1bam', 'tieopt name - scalar - untie');


# tieopt $var

Psh::Options::set_option('scalar_opt', '2bar');
Psh::Builtins::Tieopt::bi_tieopt('', [ '$scalar_opt' ]);
is($scalar_opt, '2bar', 'tieopt $var - initial retrieve');

$scalar_opt = '2wubba';
is(Psh::Options::get_option('scalar_opt'), '2wubba', 'tieopt $var - retrieve');

Psh::Options::set_option('scalar_opt', '2bam');
is($scalar_opt, '2bam', 'tieopt $var - set');

Psh::Builtins::Tieopt::bi_tieopt('', [ '-u', '$scalar_opt' ]);
$scalar_opt = 'nothing interesting';
is(scalar Psh::Options::get_option('scalar_opt'), '2bam', 'tieopt $var - scalar - untie');


# tieopt @var

Psh::Options::set_option('array_opt', [ '1foo', '1bar' ]);
Psh::Builtins::Tieopt::bi_tieopt('', [ '@array_opt' ]);
ok(eq_array(\@array_opt, [ '1foo', '1bar' ]), 'tieopt @var - initial retrieve');

@array_opt = ( '1wubba', '1fnork', '1snicker' );

ok(eq_array(scalar Psh::Options::get_option('array_opt'), ['1wubba', '1fnork', '1snicker' ]), 'tieopt @var - retrieve');

Psh::Options::set_option('array_opt', [ '1bam', '1bomb' ]);
ok(eq_array(\@array_opt, [ '1bam', '1bomb' ]), 'tieopt @var - set');

Psh::Builtins::Tieopt::bi_tieopt('', [ '-u', '@array_opt' ]);
@array_opt = ( 'nothing', 'interesting' );
ok(eq_array(scalar Psh::Options::get_option('array_opt'), [ '1bam', '1bomb' ]), 'tieopt @var - array - untie');

# tieopt %var

my %check_hash = (
    'flip'      => 18,
    'flop'      => 512,
    'blinkered' => undef,
);

Psh::Options::set_option('hash_opt', \%check_hash);
Psh::Builtins::Tieopt::bi_tieopt('', [ '%hash_opt' ]);
ok(eq_hash(\%hash_opt, \%check_hash), 'tieopt %var - initial retrieve');

$hash_opt{flip} = 22;
delete $hash_opt{flop};

%check_hash = (
    'flip'      => 22,
    'blinkered' => undef,
);

ok(eq_hash(scalar(Psh::Options::get_option('hash_opt')), \%check_hash), 'tieopt %var - retrieve');

my %new_hash = (
    'wombat' => 'strawberries',
    'snark'  => 'out',
    'voom'   => 'vom',
);

Psh::Options::set_option('hash_opt', \%new_hash);
ok(eq_hash(\%hash_opt, \%new_hash), 'tieopt %var - set');

$new_hash{'sproing'} = 'sprung';
ok(eq_hash(\%hash_opt, \%new_hash), 'tieopt %var - set 2');

Psh::Builtins::Tieopt::bi_tieopt('', [ '-u', '%hash_opt' ]);
%hash_opt = ( 'nothing' => 'interesting' );
ok(eq_hash(scalar Psh::Options::get_option('hash_opt'),  { %new_hash }), 'tieopt %var - array - untie');


# tieopt name $var

Psh::Options::set_option('2scalar_opt', '2bar');
Psh::Builtins::Tieopt::bi_tieopt('', [ '2scalar_opt', '$scalar_opt' ]);
is($scalar_opt, '2bar', 'tieopt name $var - initial retrieve');

$scalar_opt = '2wubba';
is(Psh::Options::get_option('2scalar_opt'), '2wubba', 'tieopt name $var - retrieve');

Psh::Options::set_option('2scalar_opt', '2bam');
is($scalar_opt, '2bam', 'tieopt name $var - scalar - set');

Psh::Builtins::Tieopt::bi_tieopt('', [ '-u', 'scalar_opt' ]);
$scalar_opt = 'nothing interesting';
is(scalar Psh::Options::get_option('scalar_opt'), '2bam', 'tieopt name $var - scalar - untie');

# tieopt name @var

Psh::Options::set_option('2array_opt', [ '2foo', '2bar' ]);
Psh::Builtins::Tieopt::bi_tieopt('', [ '2array_opt', '@array_opt' ]);
ok(eq_array(\@array_opt, [ '2foo', '2bar' ]), 'tieopt name @var - initial retrieve');

@array_opt = ( '2wubba', '2fnork', '2snicker' );
ok(eq_array(scalar Psh::Options::get_option('2array_opt'), ['2wubba', '2fnork', '2snicker' ]), 'tieopt name @var - retrieve');

Psh::Options::set_option('2array_opt', [ '2bam', '2bomb' ]);
ok(eq_array(\@array_opt, [ '2bam', '2bomb' ]), 'tieopt name @var - set');

Psh::Builtins::Tieopt::bi_tieopt('', [ '-u', '@array_opt' ]);
@array_opt = ( 'nothing', 'interesting' );
ok(eq_array(scalar Psh::Options::get_option('2array_opt'), [ '2bam', '2bomb' ]), 'tieopt name @var - array - untie');

# tieopt name %var

%check_hash = (
    '2flip'      => 18,
    '2flop'      => 512,
    '2blinkered' => undef,
);

Psh::Options::set_option('2hash_opt', \%check_hash);
Psh::Builtins::Tieopt::bi_tieopt('', [ '2hash_opt','%hash_opt' ]);
ok(eq_hash(\%hash_opt, \%check_hash), 'tieopt name %var - initial retrieve');

$hash_opt{'2flip'} = 22;
delete $hash_opt{'2flop'};

%check_hash = (
    '2flip'      => 22,
    '2blinkered' => undef,
);

ok(eq_hash(scalar(Psh::Options::get_option('2hash_opt')), \%check_hash), 'tieopt name %var - retrieve');

%new_hash = (
    '2wombat' => 'strawberries',
    '2snark'  => 'out',
    '2voom'   => 'vom',
);

Psh::Options::set_option('2hash_opt', \%new_hash);
ok(eq_hash(\%hash_opt, \%new_hash), 'tieopt name %var - set');

$new_hash{'2sproing'} = 'sprung';
ok(eq_hash(\%hash_opt, \%new_hash), 'tieopt name %var - set 2');

Psh::Builtins::Tieopt::bi_tieopt('', [ '-u', '%hash_opt' ]);
%hash_opt = ( 'nothing' => 'interesting' );
ok(eq_hash(scalar Psh::Options::get_option('2hash_opt'),  { %new_hash }), 'tieopt name %var - array - untie');

# tieopt path @path

  use vars qw/@path/;

  Psh::Options::set_option('path', [ '2foo', '2bar' ]);
  Psh::Builtins::Tieopt::bi_tieopt('', [ 'path', '@path' ]);
  ok(eq_array(\@path,  [ '2foo', '2bar' ]), 'tieopt name @path - initial retrieve');

  @path = ( '2wubba', '2fnork', '2snicker' );
  ok(eq_array(scalar Psh::Options::get_option('path'), ['2wubba', '2fnork', '2snicker' ]), 'tieopt name @path - retrieve');

  Psh::Options::set_option('path', [ '2bam', '2bomb' ]);
  ok(eq_array(\@path, [ '2bam', '2bomb' ]), 'tieopt name @path - set');

  Psh::Builtins::Tieopt::bi_tieopt('', [ '-u', 'path' ]);
  @path = ( 'nothing', 'interesting' );
  ok(eq_array(scalar Psh::Options::get_option('path'), [ '2bam', '2bomb' ]), 'tieopt name @path - array - untie');


Psh::Builtins::Tieopt::bi_tieopt('', [ 'array_opt', '@array_opt' ]);
@array_opt = ( '4wubba', '4fnork', '4snicker' );
ok(eq_array(scalar Psh::Options::get_option('array_opt'), ['4wubba', '4fnork', '4snicker' ]), 'tieopt -u name (array) - before');
Psh::Builtins::Tieopt::bi_tieopt('', [ '-u', 'array_opt' ]);
@array_opt = ( 'poot', 'flubber' );
ok(eq_array(scalar Psh::Options::get_option('array_opt'), ['4wubba', '4fnork', '4snicker' ]), 'tieopt -u name (array) - after');

