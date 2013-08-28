#!perl

use strict;
use warnings;

use Test::More;

use mop;

class FooMeta extends mop::class {}

class Foo meta FooMeta {}

pass("... this actually parsed!");

done_testing;