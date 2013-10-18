#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

role Foo {}
role Bar {}
role Baz {}
role Bat with Baz {}

class Quux               with Foo, Bar {}
class Quuux extends Quux with Foo, Baz {}
class Xyzzy              with Foo, Bat {}

ok(Quux->DOES($_),  "... Quux DOES $_")  for qw( Foo Bar         Quux       mop::object UNIVERSAL );
ok(Quuux->DOES($_), "... Quuux DOES $_") for qw( Foo Bar Baz     Quux Quuux mop::object UNIVERSAL );
ok(Xyzzy->DOES($_), "... Xyzzy DOES $_") for qw( Foo     Baz Bat      Xyzzy mop::object UNIVERSAL );

ok(Quux->does($_),  "... Quux does $_")  for qw( Foo Bar         );
ok(Quuux->does($_), "... Quuux does $_") for qw( Foo Bar Baz     );
ok(Xyzzy->does($_), "... Xyzzy does $_") for qw( Foo     Baz Bat );

{ local $TODO = "broken in core perl" if $] < 5.019005;
push @UNIVERSAL::ISA, 'Blorg';
ok(Quux->DOES('Blorg'));
ok(Quuux->DOES('Blorg'));
ok(Xyzzy->DOES('Blorg'));
}

done_testing;

