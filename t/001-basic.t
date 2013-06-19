#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

class Foo {

    has $foo;
    has $bar;

    method bar { 'Foo::bar' }

    method baz ($x) {
        join "::" => $self, 'baz', $x
    }

    method test ($x) {
        $foo = $x if $x;
        $foo;
    }
}

is(Foo->bar, 'Foo::bar', '... simple test works');
is(Foo->baz('hi'), 'Foo::baz::hi', '... another test works');

my $foo = Foo->new;
isa_ok($foo, 'Foo');

is($foo->bar, 'Foo::bar', '... simple test works');
is($foo->baz('hi'), $foo . '::baz::hi', '... another test works');

warn $foo->test(10);
warn $foo->test;
warn $foo->test(20);
warn $foo->test;
warn $foo->test([ 1, 2, 3 ]);
warn $foo->test;

done_testing;