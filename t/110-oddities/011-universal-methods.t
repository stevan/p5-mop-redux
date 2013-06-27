#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

my @lexical;
my @global;

class Foo { }

my $foo = Foo->new;

ok(
    $foo->DOES("Foo"),
    'DOES method (predefined by UNIVERSAL) works',
);

sub UNIVERSAL::frobnicate {
    return 42;
}

can_ok("Foo", "frobnicate");
can_ok($foo, "frobnicate");
is(Foo->can("frobnicate")->(), 42, 'Foo->can("frobnicate")->() is 42');
is($foo->can("frobnicate")->(), 42, '$foo->can("frobnicate")->() is 42');
is(Foo->frobincate, 42, 'Foo->frobincate is 42');
is($foo->frobincate, 42, '$foo->frobincate is 42');

done_testing;
