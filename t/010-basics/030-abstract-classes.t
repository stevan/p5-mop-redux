#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

class Foo {
    method bar;
}

ok(Foo->metaclass->has_required_method('bar'), '... bar is a required method');
ok(Foo->metaclass->is_abstract, '... Foo is an abstract class');

like(
    exception { Foo->new }, 
    qr/Cannot instantiate abstract class \(Foo\)/, 
    '... cannot create an instance of abstract class Foo'
);

class Bar (extends => 'Foo') {
    method bar { 'Bar::bar' }
}

ok(!Bar->metaclass->has_required_method('bar'), '... bar is a not required method');
ok(!Bar->metaclass->is_abstract, '... Bar is not an abstract class');

{
    my $bar;
    is(exception { $bar = Bar->new }, undef, '... we can create an instance of Bar');
    isa_ok($bar, 'Bar');
    isa_ok($bar, 'Foo');
}

class Baz (extends => 'Bar') {
    method baz;
}

ok(!Baz->metaclass->has_required_method('bar'), '... bar is a not required method');
ok(Baz->metaclass->has_required_method('baz'), '... baz is a required method');
ok(Baz->metaclass->is_abstract, '... Baz is an abstract class');

like(
    exception { Baz->new }, 
    qr/Cannot instantiate abstract class \(Baz\)/, 
    '... cannot create an instance of abstract class Baz'
);

class Gorch (extends => 'Foo') {}

ok(Gorch->metaclass->has_required_method('bar'), '... bar is a required method');
ok(Gorch->metaclass->is_abstract, '... Gorch is an abstract class');

like(
    exception { Gorch->new }, 
    qr/Cannot instantiate abstract class \(Gorch\)/, 
    '... cannot create an instance of abstract class Gorch'
);

done_testing;