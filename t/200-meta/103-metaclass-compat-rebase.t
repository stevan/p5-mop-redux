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

class Foo metaclass FooMeta { }

class Bar extends Foo metaclass BarMeta { }

{
    my $BarMeta = mop::get_meta('Bar');
    is($BarMeta->foo, 'FOO');
    is($BarMeta->bar, 'BAR');
}

class BazMeta extends mop::class {
    method foo { 'BAZ' }
}

eval "class Baz extends Foo metaclass BazMeta { }";
like($@, qr/Can't fix metaclass compatibility between Baz \(BazMeta\) and Foo \(FooMeta\)/);

done_testing;
