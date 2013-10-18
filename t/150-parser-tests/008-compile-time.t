#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class Foo { }
BEGIN { isa_ok(Foo->new, 'Foo') }

done_testing;
