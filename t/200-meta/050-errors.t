#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class FooMeta {
    method foo { 'FOO' }
}

eval "class Foo meta FooMeta { }";
like($@, qr/^The metaclass for Foo does not inherit from mop::class/);

eval {
    mop::class->new(
        name  => 'BarClass',
        roles => [ 'Baz' ],
    );
};
like($@, qr/^No metaclass found for these roles: Baz/);

eval {
    mop::role->new(
        name  => 'BarRole',
        roles => [ 'Baz' ],
    );
};
like($@, qr/^No metaclass found for these roles: Baz/);

class Quux {
    has $!quux;
}

my $Quux = mop::meta('Quux');
my $quux = $Quux->get_attribute('$!quux');
eval {
    $quux->set_default([]);
};
like($@, qr/^References of type \(ARRAY\) are not supported as attribute defaults \(in attribute \$!quux in class Quux\)/);

done_testing;
