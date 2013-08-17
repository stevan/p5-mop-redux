#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class Foo {
    has $foo;
    has $bar;

    method foo { $foo }
    method bar { $bar }
}

my $foo = Foo->new(foo => 'FOO', bar => 'BAR');
is($foo->foo, 'FOO');
is($foo->bar, 'BAR');

{
    my $clone = $foo->clone;
    isa_ok($clone, 'Foo');
    is($clone->foo, 'FOO');
    is($clone->bar, 'BAR');
}

{
    my $clone = $foo->clone(bar => 'RAB');
    isa_ok($clone, 'Foo');
    is($clone->foo, 'FOO');
    is($clone->bar, 'RAB');
}

class Bar extends Foo {
    has $baz;

    method new ($_foo, $_bar, $_baz) {
        $class->next::method(foo => $_foo, bar => $_bar, baz => $_baz);
    }

    method baz { $baz }
}

my $bar = Bar->new('FOO', 'BAR', 'BAZ');
is($bar->foo, 'FOO');
is($bar->bar, 'BAR');
is($bar->baz, 'BAZ');

{
    my $clone = $bar->clone;
    isa_ok($clone, 'Bar');
    is($clone->foo, 'FOO');
    is($clone->bar, 'BAR');
    is($clone->baz, 'BAZ');
}

{
    my $clone = $bar->clone(foo => 'OOF');
    isa_ok($clone, 'Bar');
    is($clone->foo, 'OOF');
    is($clone->bar, 'BAR');
    is($clone->baz, 'BAZ');
}

done_testing;
