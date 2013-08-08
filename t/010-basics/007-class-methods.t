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
        $bar + 1;
    }
}

like(
    exception { Foo->bar(10) },
    qr/^Cannot assign to the attribute\:\(\$bar\) in a method without a blessed invocant/,
    '... got the error we expected'
);

like(
    exception { Foo->bar() },
    qr/^Cannot access the attribute\:\(\$bar\) in a method without a blessed invocant/,
    '... got the error we expected'
);

my $foo = Foo->new;
isa_ok($foo, 'Foo');
{
    my $result;
    is(exception { $result = $foo->bar(10) }, undef, '... did not die');
    is($result, 11, '... and the method worked');
    is($foo->bar, 11, '... and the attribute assignment worked');
}

done_testing;
