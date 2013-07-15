#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

class Foo {
    has $foo;
    method foo { $foo }
}

my $meta = mop::util::find_meta('Foo');

my $attr = $meta->get_attribute('$foo');
is($attr->associated_class, $meta);

my $meth = $meta->get_method('foo');
is($meth->associated_class, $meta);

done_testing;
