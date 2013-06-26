#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

eval q[
    class Foo (extends => $bar) {}
];

like "$@", qr/Global symbol "\$bar" requires explicit package name/, '... got the error we expected';

done_testing;
