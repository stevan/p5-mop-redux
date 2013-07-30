#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

class Foo {

    has $bar is ro, built_by('_build_bar');
    has $baz is ro, built_by(sub { 200 });

    submethod _build_bar { 100 }
}

my $foo = Foo->new;
isa_ok($foo, 'Foo');

is($foo->bar, 100, '... the built_by trait worked with a method string');
is($foo->baz, 200, '... the built_by trait worked with a sub-ref');

done_testing;