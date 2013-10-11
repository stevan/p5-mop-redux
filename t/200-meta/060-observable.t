#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my ($called1, $called2) = (0, 0);

sub t1 {
    my ($meta) = @_;

    $meta->bind('before:EXECUTE', sub { $called1++ });
}

sub t2 {
    my ($meta) = @_;

    $meta->bind('before:EXECUTE', sub { $called2++ });
}

class Foo {
    method foo is t1, t2 { 'FOO' }
}

is(Foo->new->foo, 'FOO');
is($called1, 1);
is($called2, 1);

done_testing;
