#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my @seen;
class Foo {
    has $!attr = 10;
    method make_closure {
        return sub { push @seen, ++$!attr }
    }
}

@seen = ();

for (1..2) {
    local $SIG{__WARN__} = sub { };
    my $foo = Foo->new;
    my $c = $foo->make_closure;
    $c->();
    $c->();
}

is_deeply(\@seen, [11, 12, 11, 12]);

@seen = ();

for (1..2) {
    local $SIG{__WARN__} = sub { };
    my $c = Foo->new->make_closure;
    $c->();
    $c->();
}

is_deeply(\@seen, [11, 12, 11, 12]);

done_testing;
