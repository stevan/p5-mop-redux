#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Foo {
    has $!bar;

    method bar ($x) {
        $!bar = $x if $x;
        $!bar + 1;
    }
}

eval { Foo->bar(10) };
like(
    $@,
    qr/^Cannot assign to the attribute\:\(\$!bar\) in a method without a blessed invocant/,
    '... got the error we expected'
);

eval { Foo->bar() };
like(
    $@,
    qr/^Cannot access the attribute\:\(\$!bar\) in a method without a blessed invocant/,
    '... got the error we expected'
);

my $foo = Foo->new;
isa_ok($foo, 'Foo');
{
    my $result = eval { $foo->bar(10) };
    is($@, "", '... did not die');
    is($result, 11, '... and the method worked');
    is($foo->bar, 11, '... and the attribute assignment worked');
}

done_testing;
