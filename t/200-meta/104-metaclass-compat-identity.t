#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class IsSpecial extends mop::class { }
class CanDebug extends mop::class {
    method debug { 'debugging...' }
}

class Foo meta CanDebug { }
class Bar extends Foo meta IsSpecial { }

can_ok(mop::get_meta('Bar'), 'debug');
{ local $TODO = "making this work would be complicated - do we care?";
isa_ok(mop::get_meta('Bar'), 'IsSpecial');
}

role IsSpecialRole { }
class IsSpecial2 extends mop::class with IsSpecialRole { }

class Baz extends Foo meta IsSpecial2 { }

can_ok(mop::get_meta('Baz'), 'debug');
ok(mop::get_meta('Baz')->does('IsSpecialRole'));

done_testing;
