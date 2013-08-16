#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my $before;
my $after;

sub my_trait {
    my ($class) = @_;

    $class->bind('before:FINALIZE' => sub { $before++ });
    $class->bind('after:FINALIZE' => sub { $after++ });
}

role Foo is my_trait { }
BEGIN { is($before, 1); is($after, 1); }
class Bar is my_trait { }
BEGIN { is($before, 2); is($after, 2); }

done_testing;
