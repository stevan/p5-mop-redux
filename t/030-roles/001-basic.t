#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

role Foo {}

can_ok( mop::get_meta('Foo'), 'new' );
can_ok( mop::get_meta('Foo'), 'does' );
can_ok( mop::get_meta('Foo'), 'DOES' );
can_ok( mop::get_meta('Foo'), 'id' );
can_ok( mop::get_meta('Foo'), 'dump' );
can_ok( mop::get_meta('Foo'), 'isa' );
can_ok( mop::get_meta('Foo'), 'can' );

can_ok( mop::get_meta('Foo'), 'attribute_class' );
can_ok( mop::get_meta('Foo'), 'method_class' );

can_ok( mop::get_meta('Foo'), 'name' );
can_ok( mop::get_meta('Foo'), 'version' );
can_ok( mop::get_meta('Foo'), 'authority' );

can_ok( mop::get_meta('Foo'), 'get_method' );
can_ok( mop::get_meta('Foo'), 'has_method' );
can_ok( mop::get_meta('Foo'), 'add_method' );

can_ok( mop::get_meta('Foo'), 'get_attribute' );
can_ok( mop::get_meta('Foo'), 'has_attribute' );
can_ok( mop::get_meta('Foo'), 'add_attribute' );

is( mop::get_meta('Foo')->name, 'Foo', '... got the expected value for get_name');

role Bar {
    has $bar = 'bar';
    method bar { $bar }
}

my $method = mop::get_meta('Bar')->get_method( 'bar' );
ok( $method->isa( 'mop::method' ), '... got the method we expected' );
is( $method->name, 'bar', '... got the name of the method we expected');

my $attribute = mop::get_meta('Bar')->get_attribute( '$bar' );
ok( $attribute->isa( 'mop::attribute' ), '... got the attribute we expected' );
is( $attribute->name, '$bar', '... got the name of the attribute we expected');

done_testing;

