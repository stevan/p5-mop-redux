#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;
use mop::util 'fix_metaclass_compatibility';

sub mymethod {
    my ($meta) = @_;
    bless $meta, 'MyMethod';
}

class MyMethod extends mop::method {
    method foo { 'MyMethod' }
}

class Foo {
    method foo is mymethod { 'Foo' }
}

isa_ok(mop::get_meta('Foo')->get_method('foo'), 'MyMethod');
is(Foo->foo, 'Foo');

class Bar extends Foo {
    method foo { 'Bar' }
    method bar { 'BAR' }
}

isa_ok(mop::get_meta('Bar')->get_method('foo'), 'MyMethod');
is(Bar->foo, 'Bar');
isa_ok(mop::get_meta('Bar')->get_method('bar'), 'mop::method');
is(Bar->bar, 'BAR');

sub myothermethod {
    my ($meta) = @_;
    # XXX this isn't going to work, do we need mop::bless or something?
    bless $meta, fix_metaclass_compatibility('MyOtherMethod', $meta);
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
    # XXX this isn't going to work, do we need mop::bless or something?
    bless $meta, fix_metaclass_compatibility('MyThirdMethod', $meta);
}

class MyThirdMethod extends mop::method {
    method bar { 'MyThirdMethod' }
}

class Quux extends Foo {
    method foo is mythirdmethod { 'Quux' }
}

can_ok(mop::get_meta('Quux')->get_method('foo'), 'foo');
can_ok(mop::get_meta('Quux')->get_method('foo'), 'bar');
is(mop::get_meta('Quux')->get_method('foo')->foo, 'MyMethod');
is(mop::get_meta('Quux')->get_method('foo')->bar, 'MyThirdMethod');
is(Quux->foo, 'Quux');

done_testing;
