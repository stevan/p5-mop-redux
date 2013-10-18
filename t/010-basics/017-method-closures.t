#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my $x;

class Foo {
    method inc { ++$x }
    method dec { --$x }
}

{
    $x = 1;

    my $foo = Foo->new;

    is($x, 1);
    is($foo->inc, 2);
    is($foo->inc, 3);
    is($x, 3);
    is($foo->dec, 2);
    is($foo->dec, 1);
    is($x, 1);
}

my $y;

class Bar is abstract {
    method get_y;

    method inc { ++$y }
    method dec { --$y }
}

class Baz extends Bar {
    method get_y { $y }
}

{
    $y = 1;

    my $baz = Baz->new;

    is($baz->get_y, 1);
    is($baz->inc, 2);
    is($baz->inc, 3);
    is($baz->get_y, 3);
    is($baz->dec, 2);
    is($baz->dec, 1);
    is($baz->get_y, 1);
}

done_testing;
