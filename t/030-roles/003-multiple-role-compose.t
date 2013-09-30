#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

role Foo {
    has $!bar = 'bar';
    method bar { $!bar }
}

role Bar {
    has $!foo = 'foo';
    method foo { $!foo }
}

role Baz with Foo, Bar {
    method baz { join ", "  => $self->bar, 'baz', $self->foo }
}

class Gorch with Baz {}

ok( mop::meta('Baz')->does_role( 'Foo' ), '... Baz does the Foo role');
ok( mop::meta('Baz')->does_role( 'Bar' ), '... Baz does the Foo role');

my $bar_method = mop::meta('Baz')->get_method('bar');
ok( $bar_method->isa( 'mop::method' ), '... got a method object' );
is( $bar_method->name, 'bar', '... got the method we expected' );

my $bar_attribute = mop::meta('Baz')->get_attribute('$!bar');
ok( $bar_attribute->isa( 'mop::attribute' ), '... got an attribute object' );
is( $bar_attribute->name, '$!bar', '... got the attribute we expected' );

my $foo_method = mop::meta('Baz')->get_method('foo');
ok( $foo_method->isa( 'mop::method' ), '... got a method object' );
is( $foo_method->name, 'foo', '... got the method we expected' );

my $foo_attribute = mop::meta('Baz')->get_attribute('$!foo');
ok( $foo_attribute->isa( 'mop::attribute' ), '... got an attribute object' );
is( $foo_attribute->name, '$!foo', '... got the attribute we expected' );

my $baz_method = mop::meta('Baz')->get_method('baz');
ok( $baz_method->isa( 'mop::method' ), '... got a method object' );
is( $baz_method->name, 'baz', '... got the method we expected' );

my $gorch = Gorch->new;
isa_ok($gorch, 'Gorch');
ok($gorch->does('Baz'), '... gorch does Baz');
ok($gorch->does('Bar'), '... gorch does Bar');
ok($gorch->does('Foo'), '... gorch does Foo');

is($gorch->baz, 'bar, baz, foo', '... got the expected output');

done_testing;
