#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Fatal;

use mop;

class Foo {
    method bar { 1 }
}

{
    is(Foo->new->bar, 1);

    my $Foo = mop::get_meta('Foo');
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

    my $Bar = mop::get_meta('Bar');
    like(
        exception {
            $Bar->add_method(
                $Bar->method_class->new(
                    name => 'baz',
                    body => sub { 2 },
                )
            )
        },
        qr/^Can't call add_method on a closed class/
    );
    ok(!Bar->new->can('baz'));
}

done_testing;
