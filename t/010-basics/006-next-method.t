#!perl

use strict;
use warnings;

use Test::More;

use mop;


class Foo {
    method foo { "FOO" }
}

class FooBar extends Foo {
    method foo { $self->next::method . "-FOOBAR" }
}

class FooBarBaz extends FooBar {
    method foo { $self->next::method . "-FOOBARBAZ" }
}

class FooBarBazGorch extends FooBarBaz {
    method foo { $self->next::method . "-FOOBARBAZGORCH" }
}

my $foo = FooBarBazGorch->new;
ok( $foo->isa( 'FooBarBazGorch' ), '... the object is from class FooBarBazGorch' );
ok( $foo->isa( 'FooBarBaz' ), '... the object is from class FooBarBaz' );
ok( $foo->isa( 'FooBar' ), '... the object is from class FooBar' );
ok( $foo->isa( 'Foo' ), '... the object is from class Foo' );
ok( $foo->isa( 'mop::object' ), '... the object is derived from class Object' );

is( $foo->foo, 'FOO-FOOBAR-FOOBARBAZ-FOOBARBAZGORCH', '... got the chained super calls as expected');

done_testing;
