#!perl

use strict;
use warnings;

use Test::More;

use mop;

sub required {}
sub cached   {}

class Bar {}
class Foo extends Bar is abstract {
    has $foo is rw, required = 10;
    has $bar is rw;
    has $gorch is cached({});
}

pass("... this actually parsed!");

done_testing;