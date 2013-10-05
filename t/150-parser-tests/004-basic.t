#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Foo {
    has $bar is ro = 10;
    has $baz is rw;
}

{
    my $foo = Foo->new( baz => 20 );
    isa_ok($foo, 'Foo');

    can_ok($foo, 'bar');
    can_ok($foo, 'baz');

    is($foo->bar, 10, '... got the value we expected');
    is($foo->baz, 20, '... got the value we expected');
}

{
    my $foo = Foo->new( bar => 5, baz => 20 );
    isa_ok($foo, 'Foo');

    can_ok($foo, 'bar');
    can_ok($foo, 'baz');

    is($foo->bar, 5, '... got the value we expected');
    is($foo->baz, 20, '... got the value we expected');
}

done_testing;