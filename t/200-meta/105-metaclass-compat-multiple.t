#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

sub cant_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my ($invocant, $method) = @_;

    my $invocant_class = ref($invocant) || $invocant;
    ok(!$invocant->can($method), "!$invocant_class->can('$method')");
}

class MetaFoo extends mop::class {
    method foo { 'MetaFoo' }
}
class MetaBar extends mop::class {
    method bar { 'MetaBar' }
}
class MetaBaz extends mop::class {
    method baz { 'MetaBaz' }
}

class Foo meta MetaFoo { }
class Bar meta MetaBar { }

class Baz extends Foo meta MetaBaz { }
class Quux extends Bar meta MetaBaz { }

can_ok(mop::get_meta('Baz'), 'foo');
cant_ok(mop::get_meta('Baz'), 'bar');
can_ok(mop::get_meta('Baz'), 'baz');

cant_ok(mop::get_meta('Quux'), 'foo');
can_ok(mop::get_meta('Quux'), 'bar');
can_ok(mop::get_meta('Quux'), 'baz');

class Foo2 meta MetaFoo { }
class Bar2 meta MetaBar { }

class Baz2 extends Foo2 meta MetaBaz { }
class Quux2 extends Bar2 meta MetaBaz { }

can_ok(mop::get_meta('Baz'), 'foo');
cant_ok(mop::get_meta('Baz'), 'bar');
can_ok(mop::get_meta('Baz'), 'baz');

cant_ok(mop::get_meta('Quux'), 'foo');
can_ok(mop::get_meta('Quux'), 'bar');
can_ok(mop::get_meta('Quux'), 'baz');

is(mop::get_meta(mop::get_meta('Baz')), mop::get_meta(mop::get_meta('Baz2')));
is(mop::get_meta(mop::get_meta('Quux')), mop::get_meta(mop::get_meta('Quux2')));

class M1 extends mop::class { method m1 { 'M1' } }
class M2 extends mop::class { method m2 { 'M2' } }
class M3 extends mop::class { method m3 { 'M3' } }
class M4 extends M1         { method m4 { 'M4' } }
class M5 extends M2         { method m5 { 'M5' } }
class M6 extends M3         { method m6 { 'M6' } }

class C1 meta M4 { }
class C2 meta M5 { }

class C3 extends C1 meta M6 { }
class C4 extends C2 meta M6 { }

can_ok(mop::get_meta('C3'), 'm1');
cant_ok(mop::get_meta('C3'), 'm2');
can_ok(mop::get_meta('C3'), 'm3');
can_ok(mop::get_meta('C3'), 'm4');
cant_ok(mop::get_meta('C3'), 'm5');
can_ok(mop::get_meta('C3'), 'm6');

cant_ok(mop::get_meta('C4'), 'm1');
can_ok(mop::get_meta('C4'), 'm2');
can_ok(mop::get_meta('C4'), 'm3');
cant_ok(mop::get_meta('C4'), 'm4');
can_ok(mop::get_meta('C4'), 'm5');
can_ok(mop::get_meta('C4'), 'm6');

class C12 meta M4 { }
class C22 meta M5 { }

class C32 extends C12 meta M6 { }
class C42 extends C22 meta M6 { }

can_ok(mop::get_meta('C32'), 'm1');
cant_ok(mop::get_meta('C32'), 'm2');
can_ok(mop::get_meta('C32'), 'm3');
can_ok(mop::get_meta('C32'), 'm4');
cant_ok(mop::get_meta('C32'), 'm5');
can_ok(mop::get_meta('C32'), 'm6');

cant_ok(mop::get_meta('C42'), 'm1');
can_ok(mop::get_meta('C42'), 'm2');
can_ok(mop::get_meta('C42'), 'm3');
cant_ok(mop::get_meta('C42'), 'm4');
can_ok(mop::get_meta('C42'), 'm5');
can_ok(mop::get_meta('C42'), 'm6');

is(mop::get_meta(mop::get_meta('C3')), mop::get_meta(mop::get_meta('C32')));
is(mop::get_meta(mop::get_meta('C4')), mop::get_meta(mop::get_meta('C42')));
is(mop::get_meta(mop::get_meta('C3'))->superclass, mop::get_meta(mop::get_meta('C32'))->superclass);
is(mop::get_meta(mop::get_meta('C4'))->superclass, mop::get_meta(mop::get_meta('C42'))->superclass);

done_testing;
