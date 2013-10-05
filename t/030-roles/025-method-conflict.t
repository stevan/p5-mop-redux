#!perl

use strict;
use warnings;

use Test::More;

use mop;

role Foo {
    method foo { 'Foo::foo' }
}

role Foo2 with Foo {
    method foo { 'Foo2::foo' }
}

role Bar {
    method foo { 'Bar::foo' }
}

is_deeply([mop::meta('Foo2')->required_methods], [], '... no method conflict here');
ok(mop::meta('Foo2')->has_method('foo'), '... Foo2 has the foo method');

role FooBar with Foo, Bar {}

is_deeply([mop::meta('FooBar')->required_methods], ['foo'], '... method conflict between roles results in required method');
ok(!mop::meta('FooBar')->has_method('foo'), '... FooBar does not have the foo method');
ok(mop::meta('Foo')->has_method('foo'), '... Foo still has the foo method');
ok(mop::meta('Bar')->has_method('foo'), '... Bar still has the foo method');

class Baz with Foo {
    method foo { 'Baz::foo' }
}

is_deeply([mop::meta('Baz')->required_methods], [], '... no method conflict between class/role');
ok(mop::meta('Foo')->has_method('foo'), '... Foo still has the foo method');
is(Baz->new->foo, 'Baz::foo', '... got the right method');

class Gorch with Foo, Bar is abstract {}

ok(mop::meta('Gorch')->is_abstract, '... method conflict between roles results in required method (and an abstract class)');
is_deeply([mop::meta('Gorch')->required_methods], ['foo'], '... method conflict between roles results in required method');

role WithFinalize1 {
    method FINALIZE { }
}

role WithFinalize2 {
    method FINALIZE { }
}

eval "class MultipleFinalizeMethods with WithFinalize1, WithFinalize2 { }";
like($@, qr/Required method\(s\) \[FINALIZE\] are not allowed in MultipleFinalizeMethods unless class is declared abstract/);

role WithNew1 {
    method new { }
}

role WithNew2 {
    method new { }
}

eval "class MultipleNewMethods with WithNew1, WithNew2 { }";
like($@, qr/Required method\(s\) \[new\] are not allowed in MultipleNewMethods unless class is declared abstract/);

done_testing;
