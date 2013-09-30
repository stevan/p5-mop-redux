#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class FooMeta extends mop::class {
    method foo { 'FooMeta' }
}

class BarMeta extends mop::class {
    method foo { 'BarMeta' }
}

class Foo meta FooMeta is closed { }

class Bar meta BarMeta is closed { }

class Baz is closed { }

class Foo::Sub extends Foo {
    has $!foo;
    method foo { $!foo }
}

class Foo::Sub2 extends Foo meta FooMeta {
    has $!foo;
    method foo { $!foo }
}

class Bar::Sub extends Bar {
    has $!bar;
    method bar { $!bar }
}

class Bar::Sub2 extends Bar meta BarMeta {
    has $!bar;
    method bar { $!bar }
}

class Baz::Sub extends Baz {
    has $!baz;
    method baz { $!baz }
}

isa_ok(mop::meta('Foo'), 'FooMeta');
ok(!mop::meta('Foo')->isa('BarMeta'));
isa_ok(mop::meta('Foo::Sub'), 'FooMeta');
ok(!mop::meta('Foo::Sub')->isa('BarMeta'));
isa_ok(mop::meta('Foo::Sub2'), 'FooMeta');
ok(!mop::meta('Foo::Sub2')->isa('BarMeta'));

isa_ok(mop::meta('Bar'), 'BarMeta');
ok(!mop::meta('Bar')->isa('FooMeta'));
isa_ok(mop::meta('Bar::Sub'), 'BarMeta');
ok(!mop::meta('Bar::Sub')->isa('FooMeta'));
isa_ok(mop::meta('Bar::Sub2'), 'BarMeta');
ok(!mop::meta('Bar::Sub2')->isa('FooMeta'));

isa_ok(mop::meta('Baz'), 'mop::class');
ok(!mop::meta('Baz')->isa('FooMeta'));
ok(!mop::meta('Baz')->isa('BarMeta'));
isa_ok(mop::meta('Baz::Sub'), 'mop::class');
ok(!mop::meta('Baz::Sub')->isa('FooMeta'));
ok(!mop::meta('Baz::Sub')->isa('BarMeta'));

eval "class Quux extends Foo meta BarMeta { }";
like($@, qr/Can't fix metaclass compatibility between Foo \(FooMeta\) and Quux \(BarMeta\)/);


done_testing;
