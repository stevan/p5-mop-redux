#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

role Foo {}

can_ok( Foo->metaclass, 'attribute_class' );
can_ok( Foo->metaclass, 'method_class' );

can_ok( Foo->metaclass, 'name' );
can_ok( Foo->metaclass, 'version' );
can_ok( Foo->metaclass, 'authority' );

can_ok( Foo->metaclass, 'get_method' );
can_ok( Foo->metaclass, 'has_method' );
can_ok( Foo->metaclass, 'add_method' );

can_ok( Foo->metaclass, 'get_attribute' );
can_ok( Foo->metaclass, 'has_attribute' );
can_ok( Foo->metaclass, 'add_attribute' );

is( Foo->metaclass->name, 'Foo', '... got the expected value for get_name');

role Bar {
    has $bar = 'bar';
    method bar { $bar }
}

my $method = Bar->metaclass->get_method( 'bar' );
ok( $method->isa( 'mop::method' ), '... got the method we expected' );
is( $method->name, 'bar', '... got the name of the method we expected');

my $attribute = Bar->metaclass->get_attribute( '$bar' );
ok( $attribute->isa( 'mop::attribute' ), '... got the attribute we expected' );
is( $attribute->name, '$bar', '... got the name of the attribute we expected');

done_testing;

