#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Foo {

    has $!bar;

    method bar_func {
        return sub { 1; $!bar }
    }

    method self_func {
        return sub { 1; $self }
    }
}

my $foo = Foo->new( bar => 10 );
ok( $foo->isa( 'Foo' ), '... got the instance we expected');

my $bar = Foo->new( bar => 20 );
ok( $bar->isa( 'Foo' ), '... got the instance we expected');

my $foo_func = $foo->self_func;
is( ref $foo_func, 'CODE', '... got the code ref we expected');
my $bar_func = $bar->self_func;
is( ref $bar_func, 'CODE', '... got the code ref we expected');

my $foo_bar_func = $foo->bar_func;
is( ref $foo_bar_func, 'CODE', '... got the code ref we expected');
my $bar_bar_func = $bar->bar_func;
is( ref $bar_bar_func, 'CODE', '... got the code ref we expected');

is( $foo_func->(), $foo, '... and the function returns the $self we expected');
is( $bar_func->(), $bar, '... and the function returns the $self we expected');

is( $foo_bar_func->(), 10, '... and the function returns the $bar we expected');
is( $bar_bar_func->(), 20, '... and the function returns the $bar we expected');

done_testing;
