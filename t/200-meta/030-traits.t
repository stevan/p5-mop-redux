#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

class Foo {
    has $bar is rw;
}

my $foo = Foo->new;
isa_ok($foo, 'Foo');
can_ok($foo, 'bar');

is($foo->bar, undef, '... got the value we expected');

is(exception{ $foo->bar(10) }, undef, '... setting the value worked');

is($foo->bar, 10, '... got the value we expected');

class Bar {
    has $baz is ro;
}

my $bar = Bar->new( baz => 10 );
isa_ok($bar, 'Bar');
can_ok($bar, 'baz');

is($bar->baz, 10, '... got the value we expected');

like(
	exception{ $bar->baz(10) }, 
	qr/Cannot assign to a read-only accessor/, 
	'... setting the value worked'
);

class Baz is abstract {}

ok(mop::get_meta('Baz')->is_abstract, '... class is abstract');

done_testing;