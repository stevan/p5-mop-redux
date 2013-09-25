#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Counter {
    has $!count is ro = 0;

    method inc is overload('++') { $!count++ }
    method dec is overload('--') { $!count-- }
}

my $c = Counter->new;
isa_ok($c, 'Counter');

is($c->count, 0, '... count is 0');

$c++;
is($c->count, 1, '... count is 1');

$c++;
is($c->count, 2, '... count is 2');

$c--;
is($c->count, 1, '... count is 1 again');

$c--;
is($c->count, 0, '... count is 0 again');

done_testing;