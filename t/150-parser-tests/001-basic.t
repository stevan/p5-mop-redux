#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Bar  {}
role Baz   {}
role Gorch {}

class Foo extends Bar with Baz, Gorch {}

pass("... this actually parsed!");

done_testing;