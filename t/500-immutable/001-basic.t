#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class Foo {
    method bar { 1 }
}

{
    is(Foo->new->bar, 1);

    my $Foo = mop::meta('Foo');
    $Foo->add_method(
        $Foo->method_class->new(
            name => 'baz',
            body => sub { 2 },
        )
    );
    is(Foo->new->baz, 2);
}

class Bar is closed {
    method bar { 1 }
}

{
    is(Bar->new->bar, 1);

    my $Bar = mop::meta('Bar');
    eval {
        $Bar->add_method(
            $Bar->method_class->new(
                name => 'baz',
                body => sub { 2 },
            )
        )
    },
    like(
        $@,
        qr/^Can't call add_method on a closed class/
    );
    ok(!Bar->new->can('baz'));
}

done_testing;
