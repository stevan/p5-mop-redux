#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

class Foo {

    has $foo = 10;

    has $bar_touched is ro;
    has $baz_touched is rw;

    has $bar is ro, lazy = ${^SELF}->_build_bar;
    has $baz is ro, lazy = do { 
        ${^SELF}->baz_touched(1); 
        ${^SELF}->bar * 2 
    };

    submethod _build_bar {
        $bar_touched++;
        $foo * 5;
    }
}

for (1..2) {
    my $foo = Foo->new;
    isa_ok($foo, 'Foo');

    ok(!$foo->bar_touched, '... no bar yet');
    is($foo->bar, 50, '... bar has been generated');
    ok($foo->bar_touched, '... bar was created');

    is($foo->bar, 50, '... checking bar again');
    is($foo->bar_touched, 1, '... the lazy builder did not fire');

    ok(!$foo->baz_touched, '... no baz yet');
    is($foo->baz, 100, '... baz has been generated');
    ok($foo->baz_touched, '... baz was created');
}

done_testing;
