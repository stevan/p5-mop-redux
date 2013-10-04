#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;


class Foo {

    has $!collector = [];

    method collector { $!collector };

    method collect ($stuff) {
        push @{ $!collector } => $stuff;
    }

    method BUILD {
        $self->collect( 'Foo' );
    }
}

class Bar extends Foo {

    method BUILD {
        $self->collect( 'Bar' );
    }
}

class Baz extends Bar {

    method BUILD {
        $self->collect( 'Baz' );
    }
}

my $foo = Foo->new;
is_deeply($foo->collector, ['Foo'], '... got the expected collection');

{
    my $foo2 = Foo->new;
    isnt( $foo->collector, $foo2->collector, '... we have two different array refs' );
}

my $bar = Bar->new;
is_deeply($bar->collector, ['Foo', 'Bar'], '... got the expected collection');
isnt( $foo->collector, $bar->collector, '... we have two different array refs' );

my $baz = Baz->new;
is_deeply($baz->collector, ['Foo', 'Bar', 'Baz'], '... got the expected collection');
isnt( $foo->collector, $baz->collector, '... we have two different array refs' );
isnt( $bar->collector, $baz->collector, '... we have two different array refs' );

done_testing;
