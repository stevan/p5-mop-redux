#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class Foo {
    has $!foo = 1;
    has $!bar = 2;

    method foo ($foo) { $!foo = $foo if $foo; $!foo }
    method bar ($bar) { $!bar = $bar if $bar; $!bar }
}

{
    my $foo = Foo->new;
    is($foo->foo, 1);
    is($foo->bar, 2);
    $foo->foo(3);
    $foo->bar(4);
    is($foo->foo, 3);
    is($foo->bar, 4);
}

done_testing;
