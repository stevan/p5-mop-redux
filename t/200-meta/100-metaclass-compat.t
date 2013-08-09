#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class FooMeta extends mop::class { }

class BarMeta extends mop::class { }

class Foo metaclass FooMeta { }

class Bar metaclass BarMeta { }

class Baz { }

class Foo::Sub extends Foo { }

class Foo::Sub2 extends Foo metaclass FooMeta { }

class Bar::Sub extends Bar { }

class Bar::Sub2 extends Bar metaclass BarMeta { }

class Baz::Sub extends Baz { }

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

eval "class Quux extends Foo metaclass BarMeta { }";
like($@, qr/Can't fix metaclass compatibility between Quux \(BarMeta\) and Foo \(FooMeta\)/);

done_testing;
