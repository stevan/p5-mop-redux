#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class MetaFoo extends mop::class {
    has $!foo = "FOO";
    method foo { $!foo }
}

class MetaBar extends mop::class {
    has $!bar = "BAR";
    method bar { $!bar }
}

class Foo meta MetaFoo { }

is(mop::meta('Foo')->foo, 'FOO');

class Bar extends Foo meta MetaBar { }

is(mop::meta('Bar')->foo, 'FOO');
is(mop::meta('Bar')->bar, 'BAR');

done_testing;
