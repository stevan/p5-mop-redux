#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Foo is abstract {
    method bar;
}

ok(mop::meta('Foo')->requires_method('bar'), '... bar is a required method');
ok(mop::meta('Foo')->is_abstract, '... Foo is an abstract class');

eval { Foo->new };
like(
    $@,
    qr/Cannot instantiate abstract class \(Foo\)/,
    '... cannot create an instance of abstract class Foo'
);

class Bar extends Foo {
    method bar { 'Bar::bar' }
}

ok(!mop::meta('Bar')->requires_method('bar'), '... bar is a not required method');
ok(!mop::meta('Bar')->is_abstract, '... Bar is not an abstract class');

{
    my $bar = eval { Bar->new };
    is($@, "", '... we can create an instance of Bar');
    isa_ok($bar, 'Bar');
    isa_ok($bar, 'Foo');
}

class Baz extends Bar is abstract {
    method baz;
}

ok(!mop::meta('Baz')->requires_method('bar'), '... bar is a not required method');
ok(mop::meta('Baz')->requires_method('baz'), '... baz is a required method');
ok(mop::meta('Baz')->is_abstract, '... Baz is an abstract class');

eval { Baz->new };
like(
    $@,
    qr/Cannot instantiate abstract class \(Baz\)/,
    '... cannot create an instance of abstract class Baz'
);

class Gorch extends Foo is abstract {}

ok(mop::meta('Gorch')->requires_method('bar'), '... bar is a required method');
ok(mop::meta('Gorch')->is_abstract, '... Gorch is an abstract class');

eval { Gorch->new };
like(
    $@,
    qr/Cannot instantiate abstract class \(Gorch\)/,
    '... cannot create an instance of abstract class Gorch'
);

done_testing;
