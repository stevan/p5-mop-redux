#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

role Foo {}
role Bar {}
role Baz {}
role Bat (with => [qw(Baz)]){}

class Quux  (                    with => [qw( Foo Bar )]) {}
class Quuux (extends => q(Quux), with => [qw( Foo Baz )]) {}
class Xyzzy (                    with => [qw( Foo Bat )]) {}

ok(Quux->DOES($_),  "Quux DOES $_")  for qw( Foo Bar         Quux       mop::object UNIVERSAL );
ok(Quuux->DOES($_), "Quuux DOES $_") for qw( Foo Bar Baz     Quux Quuux mop::object UNIVERSAL );
ok(Xyzzy->DOES($_), "Xyzzy DOES $_") for qw( Foo     Baz Bat      Xyzzy mop::object UNIVERSAL );

ok(Quux->does($_),  "Quux does $_")  for qw( Foo Bar         );
ok(Quuux->does($_), "Quuux does $_") for qw( Foo Bar Baz     );
ok(Xyzzy->does($_), "Xyzzy does $_") for qw( Foo     Baz Bat );

done_testing;

