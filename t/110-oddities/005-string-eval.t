#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class Foo {
    has $!bar;
    method bar {
        eval "\$!bar ? \$!bar + 1 : die";
    }
}

{
    my $foo = Foo->new(bar => 10);
    is($foo->bar, 11);
}

{
    my $foo = Foo->new;
    is($foo->bar, undef);
}

done_testing;
