#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

role Foo {
    method foo { }
}

class Bar with Foo is closed { }

can_ok('Bar', 'foo');

done_testing;
