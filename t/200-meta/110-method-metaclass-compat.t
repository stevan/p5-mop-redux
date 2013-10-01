#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

sub mymethod {
    my ($meta) = @_;
    mop::apply_metaclass($meta, 'MyMethod');
}

class MyMethod extends mop::method {
    method foo { 'MyMethod' }
}

class Foo {
    method foo is mymethod { 'Foo' }
}

isa_ok(mop::meta('Foo')->get_method('foo'), 'MyMethod');
is(Foo->foo, 'Foo');

class Bar extends Foo {
    method foo { 'Bar' }
    method bar { 'BAR' }
}

isa_ok(mop::meta('Bar')->get_method('foo'), 'MyMethod');
is(Bar->foo, 'Bar');
isa_ok(mop::meta('Bar')->get_method('bar'), 'mop::method');
is(Bar->bar, 'BAR');

sub myothermethod {
    my ($meta) = @_;
    mop::apply_metaclass($meta, 'MyOtherMethod');
}

class MyOtherMethod extends mop::method {
    method foo { 'MyOtherMethod' }
}

eval "
class Baz extends Foo {
    method foo is myothermethod { 'Baz' }
}
";
like($@, qr/compatib/);

sub mythirdmethod {
    my ($meta) = @_;
    mop::apply_metaclass($meta, 'MyThirdMethod');
}

class MyThirdMethod extends mop::method {
    method bar { 'MyThirdMethod' }
}

class Quux extends Foo {
    method foo is mythirdmethod { 'Quux' }
}

can_ok(mop::meta('Quux')->get_method('foo'), 'foo');
can_ok(mop::meta('Quux')->get_method('foo'), 'bar');
is(mop::meta('Quux')->get_method('foo')->foo, 'MyMethod');
is(mop::meta('Quux')->get_method('foo')->bar, 'MyThirdMethod');
is(Quux->foo, 'Quux');

done_testing;
