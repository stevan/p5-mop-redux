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

{
    eval 'class Bar { method foo (€bar) { 1 } }';
    like(
        "$@",
        qr/Unrecognized character/,
        '... signature parse failure works'
    );
}

{
    eval 'class Boo { method foo ($bar { 1 } }';
    like(
        "$@",
        qr/Missing right curly or square bracket/,
        '... signature parse failure works'
    );
}

{
    eval 'class Goo } { method foo ($bar { 1 } }';
    like(
        "$@",
        qr/Unmatched right curly bracket/,
        '... class metadata parse failure works'
    );
}

done_testing