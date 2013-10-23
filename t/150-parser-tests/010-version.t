#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Foo 1.0 {}
is(mop::meta('Foo')->version, 1.0, 'can parse version "1.0"');

class Baz v1.2.3 extends Foo {}
is(mop::meta('Baz')->version, v1.2.3, 'can parse version "v1.2.3"');

role Xyzzy 42 {}
is(mop::meta('Xyzzy')->version, 42, 'can parse version "42"');

done_testing;
