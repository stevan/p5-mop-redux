#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Bar  {}
role Baz   {}
role Gorch {}
role Bling {}

class Foo extends Bar with Baz, Gorch, Bling {}

pass("... this actually parsed!");

done_testing;