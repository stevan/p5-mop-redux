#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Scalar::Util 'weaken';

use mop;

class Foo {
    has $!foo is weak_ref;
    method foo { $!foo }
}

my $weak_foo;
{
    my $foo = Foo->new;
    weaken($weak_foo = $foo);
    $foo->foo;
    is($weak_foo, $foo);
}
is($weak_foo, undef);

done_testing;

