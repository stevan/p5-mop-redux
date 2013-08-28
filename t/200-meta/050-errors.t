#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class FooMeta {
    method foo { 'FOO' }
}

eval "class Foo meta FooMeta { }";
like($@, qr/^Metaclasses must inherit from mop::class/);

done_testing;
