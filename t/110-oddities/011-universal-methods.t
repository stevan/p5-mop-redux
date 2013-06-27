#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

my @lexical;
my @global;

class Foo { }

sub UNIVERSAL::frobnicate { 42 }

my $foo = Foo->new;

can_ok("Foo", "frobnicate");
can_ok($foo, "frobnicate");
is($foo->frobincate, 42, '$foo->frobincate is 42');

done_testing;
