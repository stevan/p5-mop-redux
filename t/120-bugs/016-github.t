#!perl

use strict;
use warnings;

use Test::More;

use mop;

=pod

https://github.com/stevan/p5-mop-redux/issues/16

This behavior shown below is consistent with other languages
which have private attribute data:

  scala> class Foo { private var test = 0; def set_test (x: Int) = { test = x } }
  defined class Foo

  scala> class Baz extends Foo { private var test = 0; def get_test = test }
  defined class Baz

  scala> val x = new Baz; x.set_test(10); x.get_test;
  x: Baz = Baz@42932892
  res0: Int = 0

=cut


class Foo {
    has $!test;

    method set_test {
        $!test = $_[0];
    }
}


class Bar extends Foo {
    has $!test;

    method get_test {
        $!test
    }
}

my $bar = Bar->new;
$bar->set_test(1);
is($bar->get_test, undef, '... attributes are private to the class and therefore not virtual');

done_testing;