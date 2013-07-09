#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

my $collector;

class Foo {

    method collect ($stuff) {
        push @{ $collector } => $stuff;
    }

    submethod DEMOLISH {
        $self->collect( 'Foo' );
    }
}

class Bar extends Foo {

    submethod DEMOLISH {
        $self->collect( 'Bar' );
    }
}

class Baz extends Bar {

    submethod DEMOLISH {
        $self->collect( 'Baz' );
    }
}


$collector = [];
Foo->new;
is_deeply($collector, ['Foo'], '... got the expected collection');

$collector = [];
Bar->new;
is_deeply($collector, ['Bar', 'Foo'], '... got the expected collection');

$collector = [];
Baz->new;
is_deeply($collector, ['Baz', 'Bar', 'Foo'], '... got the expected collection');

done_testing;
