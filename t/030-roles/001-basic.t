#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

role Foo {}

can_ok( mop::meta('Foo'), 'new' );
can_ok( mop::meta('Foo'), 'does' );
can_ok( mop::meta('Foo'), 'DOES' );
can_ok( mop::meta('Foo'), 'isa' );
can_ok( mop::meta('Foo'), 'can' );

can_ok( mop::meta('Foo'), 'attribute_class' );
can_ok( mop::meta('Foo'), 'method_class' );

can_ok( mop::meta('Foo'), 'name' );
can_ok( mop::meta('Foo'), 'version' );
can_ok( mop::meta('Foo'), 'authority' );

can_ok( mop::meta('Foo'), 'get_method' );
can_ok( mop::meta('Foo'), 'has_method' );
can_ok( mop::meta('Foo'), 'add_method' );

can_ok( mop::meta('Foo'), 'get_attribute' );
can_ok( mop::meta('Foo'), 'has_attribute' );
can_ok( mop::meta('Foo'), 'add_attribute' );

is( mop::meta('Foo')->name, 'Foo', '... got the expected value for get_name');

role Bar {
    has $!bar = 'bar';
    method bar { $!bar }
}

my $Bar = mop::meta('Bar');
ok($Bar->isa('mop::role'));
ok($Bar->isa('mop::object'));
ok($Bar->DOES('mop::role'));
ok($Bar->DOES('mop::object'));
ok($Bar->can('name'));

my $method = $Bar->get_method( 'bar' );
ok( $method->isa( 'mop::method' ), '... got the method we expected' );
is( $method->name, 'bar', '... got the name of the method we expected');

my $attribute = $Bar->get_attribute( '$!bar' );
ok( $attribute->isa( 'mop::attribute' ), '... got the attribute we expected' );
is( $attribute->name, '$!bar', '... got the name of the attribute we expected');

done_testing;

