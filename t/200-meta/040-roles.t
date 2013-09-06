#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my @events;

class MethodMeta extends mop::method {
    method execute ($invocant, @args) {
        push @events, [ $self->name, $invocant ];
        $self->next::method($invocant, @args);
    }
}

class RoleMeta extends mop::role {
    method method_class { 'MethodMeta' }
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
is_deeply(\@events, [ ['foo', $foo], ['bar', $foo] ]);
is($foo->baz, 'baz');
is_deeply(\@events, [ ['foo', $foo], ['bar', $foo] ]);

is(Foo->foo, 42);
is_deeply(\@events, [ ['foo', $foo], ['bar', $foo], ['foo', 'Foo'] ]);

@events = ();

class ClassMeta extends mop::class {
    method method_class { 'MethodMeta' }
}

class BarRole {
    method foo { 42 }
    method bar { 'bar' }
}

class Bar with BarRole meta ClassMeta {
    method bar { 'BAR' }
    method baz { 'baz' }
}

my $bar = Bar->new;
is($bar->foo, 42);
is_deeply(\@events, []);
is($bar->bar, 'BAR');
is_deeply(\@events, [ ['bar', $bar] ]);
is($bar->baz, 'baz');
is_deeply(\@events, [ ['bar', $bar], ['baz', $bar] ]);

is(Bar->baz, 'baz');
is_deeply(\@events, [ ['bar', $bar], ['baz', $bar], ['baz', 'Bar'] ]);

done_testing;
