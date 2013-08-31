#!perl

use strict;
use warnings;

use Test::More;
use Test::Warn;

use mop;

warning_is {
    eval q[
        class Foo {
            has $!bar = 99;

            method bar { $!bar }

            method test ($bar) {
                join " " => ( $self->bar, $bar );
            }
        }
    ]
}
undef,
'... got the warning at compile time';

my $foo = Foo->new;

is( $foo->test('bottles of beer'), '99 bottles of beer', '... this worked as expected' );

done_testing;