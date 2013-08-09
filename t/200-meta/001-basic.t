#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

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
class Foo metaclass FooMeta {
    method hello            { 'FOO' }
    method hello_from_class { mop::get_meta($self)->static_method }
}

ok(FooMeta->isa( 'mop::object' ), '... FooMeta is an Object');
ok(FooMeta->isa( 'mop::class' ), '... FooMeta is a Class');
ok(FooMeta->isa( 'FooMeta' ), '... FooMeta is a Class');

ok(Foo->isa( 'mop::object' ), '... Foo is an Object');

is(mop::get_meta('Foo')->static_method, 'STATIC', '... called the static method on Foo');

# create an instance ...
my $foo = Foo->new;

ok($foo->isa( 'Foo' ), '... foo is a Foo');
ok($foo->isa( 'mop::object' ), '... foo is an Object');
ok(!$foo->isa( 'mop::class' ), '... foo is not a Class');
ok(!$foo->isa( 'FooMeta' ), '... foo is not a FooMeta');

like exception { $foo->static_method }, qr/^Could not find static_method in Foo/, '... got an expection here';

is($foo->hello_from_class, 'STATIC', '... got the class method via the instance however');
is($foo->hello, 'FOO', '... got the instance method however');

done_testing;