#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

eval q{
    class Foo {
        method bar { $bar }

        has $bar;
    }
};

like "$@", qr/^Global symbol \"\$bar\" requires explicit package name .*/, '... got the syntax error we expected';


done_testing