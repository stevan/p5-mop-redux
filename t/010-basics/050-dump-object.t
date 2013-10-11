#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

role Foo {
    has $!foo = 10;
}

class Bar with Foo {
    has $!bar = 20;
}

class Baz extends Bar {
    has $!baz = 30;
}

{
    my $baz = Baz->new;
    is_deeply(
        mop::dump_object($baz),
        {
            __ID__    => mop::id($baz),
            __CLASS__ => 'Baz',
            __SELF__  => $baz,
            '$!foo'   => 10,
            '$!bar'   => 20,
            '$!baz'   => 30,
        }
    );
}

# see https://github.com/pjcj/Devel--Cover/issues/72
SKIP: { skip "__SUB__ is broken with Devel::Cover", 1 if $INC{'Devel/Cover.pm'};
{
    my $bar = Bar->new(foo => [1, "foo"], bar => { quux => 10 });
    my $baz = Baz->new(baz => { a => [ 2, $bar ] });
    is_deeply(
        mop::dump_object($baz),
        {
            __ID__    => mop::id($baz),
            __CLASS__ => 'Baz',
            __SELF__  => $baz,
            '$!foo'   => 10,
            '$!bar'   => 20,
            '$!baz'   => {
                a => [
                    2,
                    {
                        __ID__    => mop::id($bar),
                        __CLASS__ => 'Bar',
                        __SELF__  => $bar,
                        '$!foo'   => [ 1, "foo" ],
                        '$!bar'   => { quux => 10 },
                    },
                ],
            },
        }
    );
}
}

done_testing;
