#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

eval q{
    class Foo {
        has $!bar;

        method bar { $baz }
    }
};

like "$@", qr/^Global symbol \"\$baz\" requires explicit package name/, '... got the syntax error we expected';

{
    eval 'class Bar { method foo (€bar) { 1 } }';
    like(
        "$@",
        qr/^Invalid sigil/,
        '... signature parse failure works'
    );
}

{
    eval 'class Boo { method foo ($bar { 1 } }';
    like(
        "$@",
        qr/Unterminated prototype for foo/,
        '... signature parse failure works'
    );
}

{
    eval 'class Goo } { method foo ($bar { 1 } }';
    like(
        "$@",
        qr/class must be followed by a block/,
        '... class metadata parse failure works'
    );
}

ok(!eval { mop::meta($_) }, "$_ no longer exists")
    for qw(Foo Bar Boo Goo);

done_testing
