#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

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

is_deeply([mop::get_meta('Foo2')->required_methods], ['foo'], '... method conflict between roles results in required method');
ok(!mop::get_meta('Foo2')->has_method('foo'), '... Foo2 does not have the foo method');

role FooBar with Foo, Bar {}

is_deeply([mop::get_meta('FooBar')->required_methods], ['foo'], '... method conflict between roles results in required method');
ok(!mop::get_meta('FooBar')->has_method('foo'), '... FooBar does not have the foo method');
ok(mop::get_meta('Foo')->has_method('foo'), '... Foo still has the foo method');
ok(mop::get_meta('Bar')->has_method('foo'), '... Bar still has the foo method');

class Baz with Foo {
    method foo { 'Baz::foo' }
}

is_deeply([mop::get_meta('Baz')->required_methods], [], '... no method conflict between class/role');
ok(mop::get_meta('Foo')->has_method('foo'), '... Foo still has the foo method');
is(Baz->new->foo, 'Baz::foo', '... got the right method');

class Gorch with Foo, Bar is abstract {}

ok(mop::get_meta('Gorch')->is_abstract, '... method conflict between roles results in required method (and an abstract class)');
is_deeply([mop::get_meta('Gorch')->required_methods], ['foo'], '... method conflict between roles results in required method');

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
