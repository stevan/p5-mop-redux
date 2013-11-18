#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

# this comes up in, for instance, Plack::Middleware::wrap

class Foo {
    has $!bar is ro;

    method baz ($bar) {
        if (ref($self)) {
            $!bar = $bar;
        }
        else {
            $self = __CLASS__->new(bar => $bar);
        }

        return $self->bar;
    }
}

is(Foo->baz('BAR-class'), 'BAR-class');
is(Foo->new->baz('BAR-instance'), 'BAR-instance');

done_testing;
