#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

# following op_next pointers isn't sufficient to traverse an optree - loops for
# instance keep the next op after a loop in op_last rather than op_next

class Foo {
    has $!bar;
    method bar {
        my $i = 10;
        while (1) {
            say $i;
            $i--;
            last unless $i;
        }
    }
}

sub barsub {
    my $i = 10;
    while (1) {
        say $i;
        $i--;
        last unless $i;
    }
}

pass("peep didn't recurse infinitely");

done_testing;
