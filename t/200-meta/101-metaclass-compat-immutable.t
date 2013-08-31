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

isa_ok(mop::get_meta('Foo'), 'FooMeta');
ok(!mop::get_meta('Foo')->isa('BarMeta'));
isa_ok(mop::get_meta('Foo::Sub'), 'FooMeta');
ok(!mop::get_meta('Foo::Sub')->isa('BarMeta'));
isa_ok(mop::get_meta('Foo::Sub2'), 'FooMeta');
ok(!mop::get_meta('Foo::Sub2')->isa('BarMeta'));

isa_ok(mop::get_meta('Bar'), 'BarMeta');
ok(!mop::get_meta('Bar')->isa('FooMeta'));
isa_ok(mop::get_meta('Bar::Sub'), 'BarMeta');
ok(!mop::get_meta('Bar::Sub')->isa('FooMeta'));
isa_ok(mop::get_meta('Bar::Sub2'), 'BarMeta');
ok(!mop::get_meta('Bar::Sub2')->isa('FooMeta'));

isa_ok(mop::get_meta('Baz'), 'mop::class');
ok(!mop::get_meta('Baz')->isa('FooMeta'));
ok(!mop::get_meta('Baz')->isa('BarMeta'));
isa_ok(mop::get_meta('Baz::Sub'), 'mop::class');
ok(!mop::get_meta('Baz::Sub')->isa('FooMeta'));
ok(!mop::get_meta('Baz::Sub')->isa('BarMeta'));

eval "class Quux extends Foo meta BarMeta { }";
like($@, qr/Can't fix metaclass compatibility between Quux \(BarMeta\) and Foo \(FooMeta\)/);


done_testing;
