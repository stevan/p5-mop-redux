#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class Foo {
    has $!foo = 1;
    has $!bar = 2;

    method foo ($foo) { $!foo = $foo if $foo; $!foo }
    method bar ($bar) { $!bar = $bar if $bar; $!bar }
}

my $foo = Foo->new;

is($foo->foo, 1);
is($foo->bar, 2);
$foo->foo(3);
$foo->bar(4);
is($foo->foo, 3);
is($foo->bar, 4);

mop::meta('Foo')->get_attribute('$!foo')->bind('after:FETCH_DATA' => sub {
    my ($event, $instance, $val) = @_;
    $$val++;
});
mop::meta('Foo')->FINALIZE;

is($foo->foo, 4);
is($foo->bar, 4);
$foo->foo(5);
$foo->bar(6);
is($foo->foo, 6);
is($foo->bar, 6);

done_testing;
