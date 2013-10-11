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
is( mop::meta($foo)->name, 'Foo', '... the class of this object is Foo' );

{
    my $foo2 = Foo->new;
    ok( $foo2->isa( 'Foo' ), '... the object is from class Foo' );
    ok( $foo2->isa( 'mop::object' ), '... the object is derived from class Object' );
    is( mop::meta($foo2)->name, 'Foo', '... the class of this object is Foo' );

    isnt( $foo, $foo2, '... these are not the same objects' );
    is( mop::meta($foo), mop::meta($foo2), '... these two objects share the same class' );
}

{
    my $foo3 = $foo->new;
    ok( $foo3->isa( 'Foo' ), '... the object is from class Foo' );

    isnt( $foo, $foo3, '... these are not the same objects' );
    is( mop::meta($foo), mop::meta($foo3), '... these two objects share the same class' );
}

class Bar {
    has $!foo;
    method foo { $!foo }
}

{
    my $bar = Bar->new;
    isa_ok($bar, 'Bar');
    is($bar->foo, undef, '... defaults to undef');
}

{
    my $bar = Bar->new( foo => 10 );
    isa_ok($bar, 'Bar');
    is($bar->foo, 10, '... keyword args to new work');
}

{
    my $bar = Bar->new({ foo => 10 });
    isa_ok($bar, 'Bar');
    is($bar->foo, 10, '... keyword args to new work');
}

class Baz {
    has $!bar;

    method new ($class: $x) {
        # NOTE:
        # this is how we do argument mangling
        # - SL
        $class->next::method( bar => $x )
    }

    method bar { $!bar }
}

{
    my $baz = Baz->new( 10 );
    isa_ok($baz, 'Baz');
    is($baz->bar, 10, '... overriding new works');
}



done_testing;
