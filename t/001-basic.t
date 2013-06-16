#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

class Foo {
    method bar { 'Foo::bar' }

    method baz ($x) {
        join "::" => $self, 'baz', $x
    }
}

is(Foo->bar, 'Foo::bar', '... simple test works');
is(Foo->baz('hi'), 'Foo::baz::hi', '... another test works');

my $foo = Foo->new;
isa_ok($foo, 'Foo');

is($foo->bar, 'Foo::bar', '... simple test works');
is($foo->baz('hi'), $foo . '::baz::hi', '... another test works');

done_testing;