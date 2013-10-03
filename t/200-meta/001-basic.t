#!perl

use strict;
use warnings;

use Test::More;

use mop;

=pod

This test immitates the Smalltalk style
parallel metaclass way of doing class
methods.

=cut

# create a meta-class (class to create classes with)
class FooMeta extends mop::class {
    method static_method { 'STATIC' }
}

# create a class (using our meta-class)
class Foo meta FooMeta {
    method hello            { 'FOO' }
    method hello_from_class { mop::meta($self)->static_method }
}

ok(FooMeta->isa( 'mop::object' ), '... FooMeta is an Object');
ok(FooMeta->isa( 'mop::class' ), '... FooMeta is a Class');
ok(FooMeta->isa( 'FooMeta' ), '... FooMeta is a Class');

ok(Foo->isa( 'mop::object' ), '... Foo is an Object');

is(mop::meta('Foo')->static_method, 'STATIC', '... called the static method on Foo');

# create an instance ...
my $foo = Foo->new;

ok($foo->isa( 'Foo' ), '... foo is a Foo');
ok($foo->isa( 'mop::object' ), '... foo is an Object');
ok(!$foo->isa( 'mop::class' ), '... foo is not a Class');
ok(!$foo->isa( 'FooMeta' ), '... foo is not a FooMeta');

eval { $foo->static_method };
like $@, qr/^Can't locate object method "static_method" via package "Foo"/, '... got an expection here';

is($foo->hello_from_class, 'STATIC', '... got the class method via the instance however');
is($foo->hello, 'FOO', '... got the instance method however');

done_testing;
