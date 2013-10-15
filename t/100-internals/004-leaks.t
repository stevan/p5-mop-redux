#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class Foo {
    has $!bar = Bar->new;
    method bar { $!bar }
    method bar_closure { sub { $!bar->foo_closure->() } }
}

class Bar {
    has $!foo = 10;
    method foo { $!foo }
    method foo_closure { sub { ++$!foo } }
}

my $foo_attr = mop::meta('Bar')->get_attribute('$!foo');
my $bar_attr = mop::meta('Foo')->get_attribute('$!bar');

{
    my $bar_id;
    {
        my $closure;
        {
            my $bar = Bar->new;
            $bar_id = mop::id($bar);
            ok($foo_attr->has_data_in_slot_for($bar_id));
            {
                is($bar->foo, 10);
                $closure = $bar->foo_closure;
            }
            ok($foo_attr->has_data_in_slot_for($bar_id));
            is($closure->(), 11);
        }
        ok($foo_attr->has_data_in_slot_for($bar_id));
        is($closure->(), 12);
    }
    ok(!$foo_attr->has_data_in_slot_for($bar_id));
}

{
    my ($foo_id, $bar_id);
    {
        my ($foo_closure, $bar_closure);
        {
            my $foo = Foo->new;
            $foo_id = mop::id($foo);
            my $bar = $foo->bar;
            $bar_id = mop::id($bar);
            ok($foo_attr->has_data_in_slot_for($bar_id));
            ok($bar_attr->has_data_in_slot_for($foo_id));
            {
                is($bar->foo, 10);
                $foo_closure = $bar->foo_closure;
                $bar_closure = $foo->bar_closure;
            }
            ok($foo_attr->has_data_in_slot_for($bar_id));
            ok($bar_attr->has_data_in_slot_for($foo_id));
            is($foo_closure->(), 11);
            is($bar_closure->(), 12);
        }
        ok($foo_attr->has_data_in_slot_for($bar_id));
        ok($bar_attr->has_data_in_slot_for($foo_id));
        is($foo_closure->(), 13);
        is($bar_closure->(), 14);
    }
    ok(!$foo_attr->has_data_in_slot_for($bar_id));
    ok(!$bar_attr->has_data_in_slot_for($foo_id));
}

done_testing;
