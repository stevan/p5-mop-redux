#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my $x;
BEGIN { $x = 1 };

class Foo {
    method inc { ++$x }
    method dec { --$x }
}

my $foo = Foo->new;

is($x, 1);
is($foo->inc, 2);
is($foo->inc, 3);
is($x, 3);
is($foo->dec, 2);
is($foo->dec, 1);
is($x, 1);

done_testing;
