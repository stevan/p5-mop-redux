#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::Moose;

use mop;

eval q{
    class Foo {
        has $bar;

        method bar { $baz }
    }
};

like "$@", qr/^Global symbol \"\$baz\" requires explicit package name/, '... got the syntax error we expected';


done_testing