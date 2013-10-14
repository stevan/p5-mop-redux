#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class Foo {
    has $!foo is rw = 'FOO';
}

class Bar {
    has $!bar is rw = 'BAR';
}

class Baz extends Foo {
    has $!baz is rw = 'BAZ';
}

class Quux extends Bar {
    has $!quux is rw = 'QUUX';
}

{
    my $foo_attr  = mop::meta('Foo')->get_attribute('$!foo');
    my $bar_attr  = mop::meta('Bar')->get_attribute('$!bar');
    my $baz_attr  = mop::meta('Baz')->get_attribute('$!baz');
    my $quux_attr = mop::meta('Quux')->get_attribute('$!quux');

    my $foo = Foo->new;
    is($foo_attr->fetch_data_in_slot_for($foo), 'FOO');
    ok(!$bar_attr->has_data_in_slot_for($foo));
    ok(!$baz_attr->has_data_in_slot_for($foo));
    ok(!$quux_attr->has_data_in_slot_for($foo));

    mop::rebless $foo, 'Bar';
    ok(!$foo_attr->has_data_in_slot_for($foo));
    is($bar_attr->fetch_data_in_slot_for($foo), 'BAR');
    ok(!$baz_attr->has_data_in_slot_for($foo));
    ok(!$quux_attr->has_data_in_slot_for($foo));

    mop::rebless $foo, 'Baz';
    is($foo_attr->fetch_data_in_slot_for($foo), 'FOO');
    ok(!$bar_attr->has_data_in_slot_for($foo));
    is($baz_attr->fetch_data_in_slot_for($foo), 'BAZ');
    ok(!$quux_attr->has_data_in_slot_for($foo));

    mop::rebless $foo, 'Quux';
    ok(!$foo_attr->has_data_in_slot_for($foo));
    is($bar_attr->fetch_data_in_slot_for($foo), 'BAR');
    ok(!$baz_attr->has_data_in_slot_for($foo));
    is($quux_attr->fetch_data_in_slot_for($foo), 'QUUX');
}

{
    my $foo = Foo->new;
    is($foo->foo, 'FOO');
    $foo->foo('abc');
    is($foo->foo, 'abc');

    mop::rebless $foo, 'Baz';
    is($foo->foo, 'abc');
    is($foo->baz, 'BAZ');

    mop::rebless $foo, 'Bar';
    ok(!$foo->can('foo'));
    ok(!$foo->can('baz'));
    is($foo->bar, 'BAR');

    mop::rebless $foo, 'Baz';
    is($foo->foo, 'FOO');
    is($foo->baz, 'BAZ');
}

package NonMop {
    BEGIN { $INC{'NonMop.pm'} = __FILE__ }
    sub new { bless {}, shift }
}

class NonMop::Sub extends NonMop is extending_non_mop {
    has $!attr is rw = 'ATTR';
}

{
    my $nonmop = NonMop::Sub->new;
    is($nonmop->attr, 'ATTR');

    mop::rebless $nonmop, 'Baz';
    ok(!$nonmop->can('attr'));
    is($nonmop->foo, 'FOO');
    is($nonmop->baz, 'BAZ');
}

done_testing;
