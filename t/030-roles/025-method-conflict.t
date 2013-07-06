#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

role Foo {
    method foo { 'Foo::foo' }
}

role Foo2 (with => ['Foo']) {
    method foo { 'Foo2::foo' }
}

role Bar {
    method foo { 'Bar::foo' }
}

is_deeply(Foo2->metaclass->required_methods, ['foo'], '... method conflict between roles results in required method');
ok(!Foo2->metaclass->has_method('foo'), '... Foo2 does not have the foo method');

role FooBar (with => ['Foo', 'Bar']) {}

is_deeply(FooBar->metaclass->required_methods, ['foo'], '... method conflict between roles results in required method');
ok(!FooBar->metaclass->has_method('foo'), '... FooBar does not have the foo method');
ok(Foo->metaclass->has_method('foo'), '... Foo still has the foo method');
ok(Bar->metaclass->has_method('foo'), '... Bar still has the foo method');

class Baz (with => ['Foo']) {
    method foo { 'Baz::foo' }
}

is_deeply(Baz->metaclass->required_methods, [], '... no method conflict between class/role');
ok(Foo->metaclass->has_method('foo'), '... Foo still has the foo method');
is(Baz->new->foo, 'Baz::foo', '... got the right method');

class Gorch (with => ['Foo', 'Bar']) {}

ok(Gorch->metaclass->is_abstract, '... method conflict between roles results in required method (and an abstract class)');
is_deeply(Gorch->metaclass->required_methods, ['foo'], '... method conflict between roles results in required method');

done_testing;