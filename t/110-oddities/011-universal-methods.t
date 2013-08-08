#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

my @lexical;
my @global;

class Foo { }

my $foo = Foo->new;

ok(
    $foo->DOES("Foo"),
    'DOES method (predefined by UNIVERSAL) works',
);

class Bar 6 { }

is(Bar->VERSION, 6, "UNIVERSAL VERSION method works");
is(exception { Bar->VERSION(5) }, undef);
is(exception { Bar->VERSION(6) }, undef);
like(
    exception { Bar->VERSION(7) },
    qr/^Bar version 7 required--this is only version 6/
);

sub UNIVERSAL::frobnicate {
    return 42;
}

can_ok("Foo", "frobnicate");
can_ok($foo, "frobnicate");
is(Foo->can("frobnicate")->(), 42, 'Foo->can("frobnicate")->() is 42');
is($foo->can("frobnicate")->(), 42, '$foo->can("frobnicate")->() is 42');
is(Foo->frobnicate, 42, 'Foo->frobnicate is 42');
is($foo->frobnicate, 42, '$foo->frobnicate is 42');

done_testing;
