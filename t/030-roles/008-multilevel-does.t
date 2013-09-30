#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

role Foo { }
role Bar with Foo { }
class Baz with Bar { }

ok(Baz->does('Bar'));
ok(Baz->does('Foo'));

role R1 { }
role R2 { }
role R3 with R1, R2 { }
class C1 with R3 { }

ok(C1->does('R3'));
ok(C1->does('R2'));
ok(C1->does('R1'));

done_testing;
