#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my ($built, $demolished);
BEGIN { ($built, $demolished) = (0, 0) }
class Meta extends mop::class {
    method BUILD    { $built++ }
    method DEMOLISH { $demolished++ }
}

BEGIN { is($built, 0); is($demolished, 0) }
class Foo meta Meta { }
BEGIN { is($built, 1); is($demolished, 0) }
class Bar meta Meta { }
BEGIN { is($built, 2); is($demolished, 0) }
class Baz meta Meta { }
BEGIN { is($built, 3); is($demolished, 0) }

mop::remove_meta('Foo');
is(mop::meta('Foo'), undef);
is($built, 3);
is($demolished, 1);
mop::remove_meta('Bar');
is(mop::meta('Bar'), undef);
is($built, 3);
is($demolished, 2);
mop::remove_meta('Baz');
is(mop::meta('Baz'), undef);
is($built, 3);
is($demolished, 3);

done_testing;
