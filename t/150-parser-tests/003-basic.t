#!perl

use strict;
use warnings;

use Test::More;

use mop;

class FooMeta extends mop::class {}

class Foo (foo => 'bar') metaclass FooMeta {}

pass("... this actually parsed!");

done_testing;