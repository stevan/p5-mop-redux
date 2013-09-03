#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

sub myattribute {
    my ($meta) = @_;
    bless $meta, 'MyAttribute';
}

class MyAttribute extends mop::attribute {
    method foo { 'MyAttribute' }
}

class Foo {
    has $!foo is myattribute = 'Foo';
    method foo { $!foo }
}

isa_ok(mop::get_meta('Foo')->get_attribute('$foo'), 'MyAttribute');
is(Foo->new->foo, 'Foo');

class Bar extends Foo {
    has $!foo = 'Bar';
    has $!bar = 'BAR';
    method foo { $!foo }
    method bar { $!bar }
}

isa_ok(mop::get_meta('Bar')->get_attribute('$foo'), 'MyAttribute');
is(Bar->new->foo, 'Bar');
isa_ok(mop::get_meta('Bar')->get_attribute('$bar'), 'mop::attribute');
is(Bar->new->bar, 'BAR');

sub myotherattribute {
    my ($meta) = @_;
    # XXX this isn't going to work, do we need mop::bless or something?
    bless $meta, 'MyOtherAttribute';
}

class MyOtherAttribute extends mop::attribute {
    method foo { 'MyOtherAttribute' }
}

eval '
class Baz extends Foo {
    has $!foo is myotherattribute = "Baz";
    method foo { $!foo }
}
';
{ local $TODO = "manual blessing won't be able to handle compat here";
like($@, qr/compatible/);
}

sub mythirdattribute {
    my ($meta) = @_;
    # XXX this isn't going to work, do we need mop::bless or something?
    bless $meta, 'MyThirdAttribute';
}

class MyThirdAttribute extends mop::attribute {
    method bar { 'MyThirdAttribute' }
}

class Quux extends Foo {
    has $!foo is mythirdattribute = "Quux";
    method foo { $!foo }
}

{ local $TODO = "manual blessing won't be able to handle compat here";
can_ok(mop::get_meta('Quux')->get_attribute('$foo'), 'foo');
}
can_ok(mop::get_meta('Quux')->get_attribute('$foo'), 'bar');
{ local $TODO = "manual blessing won't be able to handle compat here";
fail; # is(mop::get_meta('Quux')->get_attribute('$foo')->foo, 'MyAttribute');
}
is(mop::get_meta('Quux')->get_attribute('$foo')->bar, 'MyThirdAttribute');
is(Quux->new->foo, 'Quux');

done_testing;
