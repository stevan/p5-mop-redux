#!perl

use strict;
use warnings;

use Test::More;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Foo::Bar;

my $foo = Foo::Bar->new;
ok( $foo->isa( 'Foo::Bar' ), '... the object is from class Foo' );
ok( $foo->isa( 'mop::object' ), '... the object is derived from class Object' );

done_testing;
