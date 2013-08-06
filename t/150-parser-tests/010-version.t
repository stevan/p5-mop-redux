#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Foo 1.0 {}
is(mop::get_meta('Foo')->version, 1.0, 'can parse version "1.0"');

class Bar 1.00_02 extends Foo {}
is(mop::get_meta('Bar')->version, '1.00_02', 'can parse version "1.00_02"');

class Baz v1.2.3 extends Foo {}
is(mop::get_meta('Baz')->version, v1.2.3, 'can parse version "v1.2.3"');

role Quux 1.2.3 {}
is(mop::get_meta('Quux')->version, '1.2.3', 'can parse version "1.2.3"');

role Quuux undef {}
is(mop::get_meta('Quuux')->version, undef, 'can parse version "undef"');

role Xyzzy 42 {}
is(mop::get_meta('Xyzzy')->version, 42, 'can parse version "42"');

done_testing;