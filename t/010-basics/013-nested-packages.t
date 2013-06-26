#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Foo {}
class Foo::Bar {}
class Foo::Bar::Baz {}
class Foo::Bar::Baz::Gorch {}

isa_ok( Foo->new,                  'Foo'                  );
isa_ok( Foo::Bar->new,             'Foo::Bar'             );
isa_ok( Foo::Bar::Baz->new,        'Foo::Bar::Baz'        );
isa_ok( Foo::Bar::Baz::Gorch->new, 'Foo::Bar::Baz::Gorch' );

done_testing;
