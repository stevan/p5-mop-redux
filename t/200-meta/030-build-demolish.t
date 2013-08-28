#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my ($built, $demolished);
BEGIN { ($built, $demolished) = (0, 0) }
class Meta extends mop::class {
    submethod BUILD    { $built++ }
    submethod DEMOLISH { $demolished++ }
}

BEGIN { is($built, 0); is($demolished, 0) }
class Foo meta Meta { }
BEGIN { is($built, 1); is($demolished, 0) }
class Bar meta Meta { }
BEGIN { is($built, 2); is($demolished, 0) }
class Baz meta Meta { }
BEGIN { is($built, 3); is($demolished, 0) }

mop::util::uninstall_meta(mop::get_meta('Foo'));
is($built, 3);
is($demolished, 1);
mop::util::uninstall_meta(mop::get_meta('Bar'));
is($built, 3);
is($demolished, 2);
mop::util::uninstall_meta(mop::get_meta('Baz'));
is($built, 3);
is($demolished, 3);

done_testing;
