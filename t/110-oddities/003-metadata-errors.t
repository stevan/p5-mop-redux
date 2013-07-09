#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

eval q[
    class Foo extends $bar {}
];

like "$@", qr/\$bar is not a module name/, '... got the error we expected';

done_testing;
