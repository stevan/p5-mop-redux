#!perl

use strict;
use warnings;

use Test::More;

use mop;

eval q[
    class Foo extends $bar {}
];

like "$@", qr/\$bar is not a valid class name/, '... got the error we expected';

done_testing;
