#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

role Foo {
    method bar;
}

class Gorch ( with => 'Foo' ) {}

ok(Gorch->metaclass->is_abstract, '... composing a role with still required methods creates an abstract class');
like(
    exception { Gorch->new },
    qr/Cannot instantiate abstract class \(Gorch\)/,
    '... cannot create an instance of Gorch'
);

done_testing;
