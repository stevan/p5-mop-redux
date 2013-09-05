#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my @events;

class RoleMeta::Method extends mop::method {
    method execute ($invocant, @args) {
        push @events, [ $self->name, $invocant ];
        $self->next::method($invocant, @args);
    }
}

class RoleMeta extends mop::role {
    method method_class { 'RoleMeta::Method' }
}

role FooRole meta RoleMeta {
    method foo { 42 }
    method bar { 'bar' }
}

class Foo with FooRole {
    method bar { 'BAR' }
    method baz { 'baz' }
}

my $foo = Foo->new;
is($foo->foo, 42);
is_deeply(\@events, [ ['foo', $foo] ]);
is($foo->bar, 'BAR');
is_deeply(\@events, [ ['foo', $foo] ]);
is($foo->baz, 'baz');
is_deeply(\@events, [ ['foo', $foo] ]);

is(Foo->foo, 42);
is_deeply(\@events, [ ['foo', $foo], ['foo', 'Foo'] ]);

done_testing;
