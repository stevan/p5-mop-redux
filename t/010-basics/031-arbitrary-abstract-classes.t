#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

class Foo is abstract {}

ok(mop::meta('Foo')->is_abstract, '... Foo is an abstract class');

like(
    exception { Foo->new },
    qr/Cannot instantiate abstract class \(Foo\)/,
    '... cannot create an instance of abstract class Foo'
);

class Bar extends Foo {}

ok(!mop::meta('Bar')->is_abstract, '... Bar is not an abstract class');

{
    my $bar;
    is(exception { $bar = Bar->new }, undef, '... we can create an instance of Bar');
    isa_ok($bar, 'Bar');
    isa_ok($bar, 'Foo');
}

done_testing;