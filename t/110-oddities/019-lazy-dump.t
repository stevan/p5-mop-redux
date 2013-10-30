#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class Foo {
    has $!foo is lazy, ro = Foo->new;
}

isa_ok(Foo->new, 'Foo');
isa_ok(Foo->new->foo, 'Foo');
isa_ok(Foo->new->foo->foo, 'Foo');

{
    my $foo = Foo->new;
    is_deeply(
        mop::dump_object($foo),
        {
            __CLASS__ => 'Foo',
            __SELF__  => $foo,
            __ID__    => mop::id($foo),
            '$!foo'   => undef,
        }
    );

    is($foo->foo, $foo->foo);
    isa_ok($foo->foo, 'Foo');

    is_deeply(
        mop::dump_object($foo),
        {
            __CLASS__ => 'Foo',
            __SELF__  => $foo,
            __ID__    => mop::id($foo),
            '$!foo'   => {
                __CLASS__ => 'Foo',
                __SELF__  => $foo->foo,
                __ID__    => mop::id($foo->foo),
                '$!foo'   => undef,
            },
        }
    );
}

done_testing;
