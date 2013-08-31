#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

=pod

This test illustrates how the attributes are
private and allocated on a per-class basis.
So when you override an attribute in a subclass
the methods of the superclass will not get
the value 'virtually', since the storage is
class specific.

This is perhaps not ideal, the older p5-mop
prototype did the opposite and in some ways
that is more what I think people would expect.

The solution to making this work like the
older prototype would be to lookup the
attribute storage hash on each method call,
this should then give us the virtual behavior
but it seems a lot of overhead, so perhaps
I will just punt until we do the real thing.

=cut

use mop;

class Foo {
    has $!bar = 10;
    method bar { $!bar }
}

class FooBar extends Foo {
    has $!bar = 100;
    method derived_bar { $!bar }
}

my $foobar = FooBar->new;

is($foobar->bar, undef, '... got the expected value (for the superclass method)');
is($foobar->derived_bar, 100, '... got the expected value (for the derived method)');

done_testing;
