#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Foo {
    has $!bar is rw;
}

class Bar {
    has $!foo is rw, weak_ref;
}

my $foo = Foo->new;
my $bar = Bar->new;

$bar->foo($foo);
$foo->bar($bar);

my $attr = mop::meta('Bar')->get_attribute('$!foo');

ok($attr->is_data_in_slot_weak_for($bar), '... this is weak');

#warn $foo->bar;

is($foo->bar, $bar, '... these match');
is($bar->foo, $foo, '... these match');

undef $foo;

is($bar->foo, undef, '... weak ref reaped');


done_testing;
