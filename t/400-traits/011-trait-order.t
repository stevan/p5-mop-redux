#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my @events;

sub my_trait {
    my ($class) = @_;

    push @events, ['trait', [ map { $_->name } $class->methods ]];

    $class->bind('before:FINALIZE', sub {
        push @events, ['before:FINALIZE', [ map { $_->name } $_[0]->methods ]];
    });
    $class->bind('after:FINALIZE', sub {
        push @events, ['after:FINALIZE', [ map { $_->name } $_[0]->methods ]];
    });
}

class FooMeta extends mop::class {
    method FINALIZE {
        push @events, ['enter FINALIZE', [ map { $_->name } $self->methods ]];
        $self->next::method;
        push @events, ['leave FINALIZE', [ map { $_->name } $self->methods ]];
    }
}

role FooRole {
    method foo { }
}

class Foo with FooRole meta FooMeta is my_trait {
}

is_deeply(
    \@events,
    [
        ['trait',           []     ],
        ['enter FINALIZE',  []     ],
        ['before:FINALIZE', ['foo']],
        ['after:FINALIZE',  ['foo']],
        ['leave FINALIZE',  ['foo']],
    ]
);

done_testing;
