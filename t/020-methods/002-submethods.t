#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class Foo {
    submethod foo { 42 }
    method bar { $self->foo }
}

class Bar1 extends Foo { }

eval { Bar1->new->bar };
like($@, qr/Could not find foo in Bar1=/);

class Bar2 extends Foo {
    submethod foo { 666 }
}

is(Bar2->new->bar, 666);

class Bar3 extends Foo {
    method foo { 666 }
}

is(Bar3->new->bar, 666);

done_testing;
