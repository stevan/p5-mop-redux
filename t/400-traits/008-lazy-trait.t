#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Foo {

    has $!foo = 10;

    has $!bar_touched is ro;
    has $!baz_touched is rw;

    has $!bar is ro, lazy = $_->_build_bar;
    has $!baz is ro, lazy = do {
        $_->baz_touched(1);
        $_->bar * 2
    };

    method _build_bar {
        $!bar_touched++;
        $!foo * 5;
    }

    method has_bar {
        mop::meta($self)->get_attribute('$!bar')->has_data_in_slot_for($self)
    }

    method clear_bar {
        $!bar_touched--;
        undef $!bar;
    }
}

for (1..2) {
    my $foo = Foo->new;
    isa_ok($foo, 'Foo');

    ok(!$foo->has_bar, '... no bar yet');
    ok(!$foo->bar_touched, '... no bar yet');
    is($foo->bar, 50, '... bar has been generated');
    ok($foo->has_bar, '... have bar yet');
    is($foo->bar_touched, 1, '... bar was created');

    is($foo->bar, 50, '... checking bar again');
    is($foo->bar_touched, 1, '... the lazy builder did not fire');

    $foo->clear_bar;
    ok(!$foo->has_bar, '... no bar again');
    is($foo->bar_touched, 0, '... we cleared bar');

    is($foo->bar, 50, '... init bar again');
    is($foo->bar_touched, 1, '... the lazy builder fired again');
    ok($foo->has_bar, '... have bar yet');

    ok(!$foo->baz_touched, '... no baz yet');
    is($foo->baz, 100, '... baz has been generated');
    ok($foo->baz_touched, '... baz was created');
}

done_testing;
