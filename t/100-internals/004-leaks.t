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

my $foo_storage = mop::get_meta('Bar')->get_attribute('$!foo')->storage;
my $bar_storage = mop::get_meta('Foo')->get_attribute('$!bar')->storage;

{
    my $bar_id;
    {
        my $closure;
        {
            my $bar = Bar->new;
            $bar_id = mop::util::get_object_id($bar);
            ok(exists $foo_storage->{$bar_id});
            {
                is($bar->foo, 10);
                $closure = $bar->foo_closure;
            }
            ok(exists $foo_storage->{$bar_id});
            is($closure->(), 11);
        }
        ok(exists $foo_storage->{$bar_id});
        is($closure->(), 12);
    }
    ok(!exists $foo_storage->{$bar_id});
}

{
    my ($foo_id, $bar_id);
    {
        my ($foo_closure, $bar_closure);
        {
            my $foo = Foo->new;
            $foo_id = mop::util::get_object_id($foo);
            my $bar = $foo->bar;
            $bar_id = mop::util::get_object_id($bar);
            ok(exists $foo_storage->{$bar_id});
            ok(exists $bar_storage->{$foo_id});
            {
                is($bar->foo, 10);
                $foo_closure = $bar->foo_closure;
                $bar_closure = $foo->bar_closure;
            }
            ok(exists $foo_storage->{$bar_id});
            ok(exists $bar_storage->{$foo_id});
            is($foo_closure->(), 11);
            is($bar_closure->(), 12);
        }
        ok(exists $foo_storage->{$bar_id});
        ok(exists $bar_storage->{$foo_id});
        is($foo_closure->(), 13);
        is($bar_closure->(), 14);
    }
    ok(!exists $foo_storage->{$bar_id});
    ok(!exists $bar_storage->{$foo_id});
}

done_testing;
