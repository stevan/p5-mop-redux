#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class FooMeta {
    method foo { 'FOO' }
}

eval "class Foo meta FooMeta { }";
like($@, qr/^The metaclass for Foo does not inherit from mop::class/);

done_testing;
