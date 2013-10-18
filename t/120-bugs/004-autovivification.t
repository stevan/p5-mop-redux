#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

BEGIN {
    plan skip_all => "autovivification is required"
        unless eval { require autovivification };
}

no autovivification; # order is important - must come after 'use mop'

class Foo {
  has $!unused;
  method segfault {
    # bad code is injected here
    42
  }
}

Foo->segfault;

pass();

done_testing;
