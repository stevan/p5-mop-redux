#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

role Foo {
    method foo { }
}

eval "
class Bar with Foo is closed { }
";
{ local $TODO = "hmmm, more trait application order issues";
is($@, "");

can_ok('Bar', 'foo');
}

done_testing;
