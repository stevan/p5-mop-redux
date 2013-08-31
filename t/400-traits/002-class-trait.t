#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

class Foo is rw {
    has $!bar;
    has $!baz;
}

my $foo = Foo->new;
isa_ok($foo, 'Foo');
can_ok($foo, 'bar');
can_ok($foo, 'baz');

is($foo->bar, undef, '... got the value we expected');
is($foo->baz, undef, '... got the value we expected');

is(exception{ $foo->bar(10) }, undef, '... setting the value worked');
is(exception{ $foo->baz(20) }, undef, '... setting the value worked');

is($foo->bar, 10, '... got the value we expected');
is($foo->baz, 20, '... got the value we expected');

class Bar is ro {
    has $!baz;
    has $!foo;
}

my $bar = Bar->new( baz => 10, foo => 20 );
isa_ok($bar, 'Bar');
can_ok($bar, 'baz');
can_ok($bar, 'foo');

is($bar->baz, 10, '... got the value we expected');
is($bar->foo, 20, '... got the value we expected');

like(
    exception{ $bar->baz(40) },
    qr/Cannot assign to a read-only accessor/,
    '... setting the value worked'
);

like(
    exception{ $bar->foo(30) },
    qr/Cannot assign to a read-only accessor/,
    '... setting the value worked'
);

done_testing;
