#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class Foo {
    has $!foo;
    method foo { $!foo }
}

my $attr = mop::meta('Foo')->get_attribute('$!foo');
my $meth = mop::meta('Foo')->get_method('foo');

is(mop::meta($attr)->get_attribute('$!associated_meta')->fetch_data_in_slot_for($attr), $attr->associated_meta);
is($attr->associated_meta, mop::meta('Foo'));

is(mop::meta($meth)->get_attribute('$!associated_meta')->fetch_data_in_slot_for($meth), $meth->associated_meta);
is($meth->associated_meta, mop::meta('Foo'));

done_testing;
