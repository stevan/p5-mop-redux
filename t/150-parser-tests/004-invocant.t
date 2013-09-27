#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class Foo {
    method foo              { $self }
    method bar  ()          { $self }
    method baz  ($this:)    { $this }
    method quux ($this: $x) { $this, $x }
    method blorg ( $this : ) { $this }
    method blorgg (
        $this
        :
        $x
    ) { $this, $x }
}

is(Foo->foo, 'Foo');
is(Foo->bar, 'Foo');
is(Foo->baz, 'Foo');
is_deeply([ Foo->quux(1) ], [ 'Foo', 1 ]);
is(Foo->blorg, 'Foo');
is_deeply([ Foo->blorgg(1) ], [ 'Foo', 1 ]);

done_testing;
