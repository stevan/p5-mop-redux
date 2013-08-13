#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my $built;
BEGIN { $built = 0 }
class MetaMeta extends mop::class {
    submethod BUILD { $built++ }
}

class Meta extends mop::class metaclass MetaMeta { }

class Foo metaclass Meta is closed {
    method foo { 'FOO' }
    method bar { 'BAR' }
}

class Bar metaclass Meta is closed {
    method foo { 'FOOBAR' }
    method baz { 'BAZ' }
}

class Baz metaclass Meta is closed {
    method quux { 'QUUX' }
}

can_ok('Foo', 'foo');
can_ok('Foo', 'bar');
ok(!Foo->can('baz'));
can_ok('Bar', 'foo');
can_ok('Bar', 'baz');
ok(!Bar->can('bar'));

is(mop::get_meta(mop::get_meta('Foo')), mop::get_meta(mop::get_meta('Bar')));
# should have one instance built for Meta, and one for the closed form of Meta.
# in other words, closing multiple classes that all use the same metaclass
# shouldn't end up creating multiple closed versions of the metaclass
is($built, 2);

done_testing;
