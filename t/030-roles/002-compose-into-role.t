#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

role Foo {
    has $bar = 'bar';
    method bar { $bar }
}

role Baz ( with => [ 'Foo' ] ) {
    method baz { join ", "  => $self->bar, 'baz' }
}

ok( Baz->metaclass->does_role( 'Foo' ), '... Baz does the Foo role');

my $bar_method = Baz->metaclass->get_method('bar');
ok( $bar_method->isa( 'mop::method' ), '... got a method object' );
is( $bar_method->name, 'bar', '... got the method we expected' );

my $bar_attribute = Baz->metaclass->get_attribute('$bar');
ok( $bar_attribute->isa( 'mop::attribute' ), '... got an attribute object' );
is( $bar_attribute->name, '$bar', '... got the attribute we expected' );

my $baz_method = Baz->metaclass->get_method('baz');
ok( $baz_method->isa( 'mop::method' ), '... got a method object' );
is( $baz_method->name, 'baz', '... got the method we expected' );

done_testing;
