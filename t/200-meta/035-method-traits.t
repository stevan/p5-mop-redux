#!perl

use strict;
use warnings;

use Test::More;

use mop;

sub overload {
    my $meta = shift;
    my (%args) = @_;
}

class Foo {
    has $val;

    method add ($b) is overload('+') {
        $val + $b
    }

    method subtract ($b) is overload('-') {
        $val - $b
    }

    method equals ($b) is overload('==') {
        $val == $b
    }
}

my $foo = Foo->new( val => 10 );

is($foo + 1, 11, '... got the right value');
is($foo - 1, 9,  '... got the right value');

ok($foo == 10, '... got the right value');

pass("... this actually parsed!");

done_testing;