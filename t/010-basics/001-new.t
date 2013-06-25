#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

=pod

Every new instance created should be a new reference
but it should link back to the same class data.

=cut

class Foo {}

my $foo = Foo->new;
ok( $foo->isa( 'Foo' ), '... the object is from class Foo' );
ok( $foo->isa( 'mop::object' ), '... the object is derived from class Object' );
is( $foo->metaclass->name, 'Foo', '... the class of this object is Foo' );

{
    my $foo2 = Foo->new;
    ok( $foo2->isa( 'Foo' ), '... the object is from class Foo' );
    ok( $foo2->isa( 'mop::object' ), '... the object is derived from class Object' );
    is( $foo2->metaclass->name, 'Foo', '... the class of this object is Foo' );

    isnt( $foo, $foo2, '... these are not the same objects' );
    is( $foo->metaclass, $foo2->metaclass, '... these two objects share the same class' );
}

done_testing;
