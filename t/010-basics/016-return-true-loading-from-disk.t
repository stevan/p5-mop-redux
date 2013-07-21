#!perl

use strict;
use warnings;

use Test::More;

use FindBin;
use lib "$FindBin::Bin/../lib";

use ReturnTrue;

my $x = ReturnTrue->new;
ok( $x->isa( 'ReturnTrue' ), '... the object is from class Foo' );
ok( $x->isa( 'mop::object' ), '... the object is derived from class Object' );

is($x->horray, 'HORRAY!', '... got the right value');

done_testing;
