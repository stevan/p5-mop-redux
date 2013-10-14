#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Foo {
    has $!val is ro;

    method add ($b) is overload('+') {
        $!val + $b
    }

    method subtract ($b) is overload('-') {
        $!val - $b
    }

    method equals ($b) is overload('==') {
        $!val == $b
    }

    method to_string is overload('""') {
        "<foo value=$!val />";
    }

    method to_hash is overload('%{}') {
        { val => $!val }
    }
}

{
    my $foo = Foo->new( val => 10 );

    is($foo + 1, 11, '... got the right value from +');
    is($foo - 1, 9,  '... got the right value from -');

    ok($foo == 10, '... got the right value from ==');

    is("$foo", "<foo value=10 />", '... got the right value from stringification');

    is_deeply({ %$foo }, { val => 10 }, '... got the right value from hash dereference');
}

class Bar extends Foo {
    method to_string is overload('""') {
        "<bar value=" . $self->val . " />";
    }
}

{
    my $bar = Bar->new( val => 10 );

    is($bar + 1, 11, '... got the right value from +');
    is($bar - 1, 9,  '... got the right value from -');

    ok($bar == 10, '... got the right value from ==');

    is("$bar", "<bar value=10 />", '... got the right value from stringification');

    is_deeply({ %$bar }, { val => 10 }, '... got the right value from hash dereference');
}

done_testing;