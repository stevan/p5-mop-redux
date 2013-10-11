#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use 5.016;

use mop;

my ($called1, $called2);

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

$called1 = 0;
$called2 = 0;
is(Foo->new->foo, 'FOO');
is($called1, 1);
is($called2, 1);

sub every_other {
    my ($meta) = @_;

    $meta->bind('before:EXECUTE', sub {
        my $event1 = __SUB__;
        $called1++;
        $meta->unbind('before:EXECUTE', $event1);
        $meta->bind('before:EXECUTE', sub {
            my $event2 = __SUB__;
            $called2++;
            $meta->unbind('before:EXECUTE', $event2);
            $meta->bind('before:EXECUTE', $event1);
        });
    });
}

class Bar {
    method bar is every_other { 'BAR' }
}

$called1 = 0;
$called2 = 0;
my $bar = Bar->new;
is($called1, 0);
is($called2, 0);
is($bar->bar, 'BAR');
is($called1, 1);
is($called2, 0);
is($bar->bar, 'BAR');
is($called1, 1);
is($called2, 1);
is($bar->bar, 'BAR');
is($called1, 2);
is($called2, 1);
is($bar->bar, 'BAR');
is($called1, 2);
is($called2, 2);

done_testing;
