#!perl

use strict;
use warnings;

use Test::More;

use mop;

{
    my $warning;
    local $SIG{__WARN__} = sub { $warning .= $_[0] };
    eval q[
        class Foo {
            has $!bar = 99;

            method bar { $!bar }

            method test ($bar) {
                join " " => ( $self->bar, $bar );
            }
        }
    ];
    is($warning, undef, '... got no warning at compile time');
}

my $foo = Foo->new;

is( $foo->test('bottles of beer'), '99 bottles of beer', '... this worked as expected' );

done_testing;