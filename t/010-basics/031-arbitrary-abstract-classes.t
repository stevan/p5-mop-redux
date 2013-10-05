#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Foo is abstract {}

ok(mop::meta('Foo')->is_abstract, '... Foo is an abstract class');

eval { Foo->new };
like(
    $@,
    qr/Cannot instantiate abstract class \(Foo\)/,
    '... cannot create an instance of abstract class Foo'
);

class Bar extends Foo {}

ok(!mop::meta('Bar')->is_abstract, '... Bar is not an abstract class');

{
    my $bar = eval { Bar->new };
    is($@, "", '... we can create an instance of Bar');
    isa_ok($bar, 'Bar');
    isa_ok($bar, 'Foo');
}

done_testing;
