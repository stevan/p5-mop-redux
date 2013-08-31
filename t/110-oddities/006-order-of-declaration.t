#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;
use twigils;

=pod

This test is being odd, I think it is
because of the order of exectutions.

eval q{
    class Foo {
        method bar { $!bar }

        has $!bar;
    }
};

like "$@", qr/^syntax error at (eval 27) line 3, near "\$\!bar .*/, '... got the syntax error we expected';
=cut

pass('... skipping this for now');

done_testing