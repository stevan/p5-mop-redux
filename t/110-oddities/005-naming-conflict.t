#!perl

use strict;
use warnings;

use Test::More;

=pod

This used to work differently in the old
prototype, because Bar was turned into a
subroutine. However, this is no longer
the case since we are generating packages
now.

=cut

{
    package Foo;
    use mop;
    class Bar {
        method go {
            return 'package Foo, class Bar';
        }
    }
}


{
    package Foo::Bar;
    sub new {
        bless []=> shift;
    }
    sub go {
        return 'package Foo::Bar';
    }
}

is(
    Foo::Bar->new->go,
    'package Foo::Bar',
);

is(
    Foo::Bar->new->go,
    'package Foo::Bar',
);

done_testing;