#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

role Foo {
    method bar;
}

class Gorch with Foo is abstract {}

ok(mop::meta('Gorch')->is_abstract, '... composing a role with still required methods creates an abstract class');
eval { Gorch->new };
like(
    $@,
    qr/Cannot instantiate abstract class \(Gorch\)/,
    '... cannot create an instance of Gorch'
);

done_testing;
