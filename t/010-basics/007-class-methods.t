#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

class Foo {
    has $bar;

    method bar ($x) {
        $bar = $x if $x;
        $bar;
    }
}

like(
    exception { Foo->bar(10) }, 
    qr/^Cannot assign to the attribute\:\(\$bar\) in a method without a blessed invocant/,
    '... got the error we expected'
);

my $foo = Foo->new;
isa_ok($foo, 'Foo');
{
    my $result;
    is(exception { $result = $foo->bar(10) }, undef, '... did not die');
    is($result, 10, '... and the method worked');
    is($foo->bar, 10, '... and the attribute assignment worked');
}

done_testing;