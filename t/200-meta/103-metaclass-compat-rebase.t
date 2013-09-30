#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class FooMeta extends mop::class {
    method foo { 'FOO' }
}

class BarMeta extends mop::class {
    method bar { 'BAR' }
}

class Foo meta FooMeta { }

class Bar extends Foo meta BarMeta { }

{
    my $BarMeta = mop::meta('Bar');
    is($BarMeta->foo, 'FOO');
    is($BarMeta->bar, 'BAR');
}

class BazMeta extends mop::class {
    method foo { 'BAZ' }
}

eval "class Baz extends Foo meta BazMeta { }";
like($@, qr/Can't fix metaclass compatibility between Foo \(FooMeta\) and Baz \(BazMeta\)/);

done_testing;
