#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Foo {

    has $!bar is ro = $_->_build_bar;
    has $!baz is ro = 200;

    method _build_bar { 100 }
}

my $foo = Foo->new;
isa_ok($foo, 'Foo');

is($foo->bar, 100, '... the revised traitless build process worked with a method string');
is($foo->baz, 200, '... the revised traitless build process worked with a sub-ref');

done_testing;
