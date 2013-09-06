#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

sub mymethod {
    my ($meta) = @_;
    bless $meta, 'MyMethod';
}

class MyMethod extends mop::method {
    method foo { 'MyMethod' }
}

role FooRole {
    method foo is mymethod { 'FooRole' }
}

class Foo with FooRole { }

isa_ok(mop::get_meta('FooRole')->get_method('foo'), 'MyMethod');
isa_ok(mop::get_meta('Foo')->get_method('foo'), 'MyMethod');
is(Foo->foo, 'FooRole');

class Bar with FooRole {
    method foo { 'Bar' }
}

isa_ok(mop::get_meta('Bar')->get_method('foo'), 'MyMethod');
is(Bar->foo, 'Bar');

role BarRole with FooRole {
    method foo { 'BarRole' }
}

{ local $TODO = "need to work out the issues with role composition first";
isa_ok(mop::get_meta('BarRole')->get_method('foo'), 'MyMethod');
}

class Baz with BarRole {
    method foo { 'Baz' }
}

{ local $TODO = "this will require us to do better tracking of conflicts";
isa_ok(mop::get_meta('Baz')->get_method('foo'), 'MyMethod');
}
is(Baz->foo, 'Baz');

role R1 {
    method foo is mymethod { 'R1' }
}

role R2 {
    method foo { 'R2' }
}

class C1 with R1, R2 {
    method foo { 'C1' }
}

{ local $TODO = "this will require us to do better tracking of conflicts";
isa_ok(mop::get_meta('C1')->get_method('foo'), 'MyMethod');
}
is(C1->foo, 'C1');

done_testing;
