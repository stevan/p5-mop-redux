#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class Foo is repr('HASH') {
    has $!attr = 'ATTR';

    method attr { $!attr }
    method foo  { 'FOO' }
    method bar  { 'BAR' }
}

{
    package Bar;
    use parent 'Foo';
    sub bar { 'BAZ' }
}

{
    my $bar = Bar->new;
    is($bar->attr, 'ATTR');
    is($bar->foo, 'FOO');
    is($bar->bar, 'BAZ');
}

{
    my $bar = Bar->new(attr => 'RTTA');
    is($bar->attr, 'RTTA');
    is($bar->foo, 'FOO');
    is($bar->bar, 'BAZ');
}

{
    package Baz;
    use parent 'Foo';
    sub bar { my $self = shift; $self->SUPER::bar . 'BAZ' }
}

{
    my $baz = Baz->new;
    is($baz->attr, 'ATTR');
    is($baz->foo, 'FOO');
    is($baz->bar, 'BARBAZ');
}

{
    my $baz = Baz->new(attr => 'RTTA');
    is($baz->attr, 'RTTA');
    is($baz->foo, 'FOO');
    is($baz->bar, 'BARBAZ');
}

{
    package Quux;
    use parent 'Foo';
    sub new {
        my $class = shift;
        my (%opts) = @_;

        my $self = $class->SUPER::new(%opts);
        $self->{extra} = $opts{extra} // 'EXTRA';

        return $self;
    }
    sub extra { $_[0]->{extra} }
}

{
    my $quux = Quux->new;
    is($quux->attr, 'ATTR');
    is($quux->extra, 'EXTRA');
}

{
    my $quux = Quux->new(attr => 'RTTA');
    is($quux->attr, 'RTTA');
    is($quux->extra, 'EXTRA');
}

{
    my $quux = Quux->new(extra => 'ARTXE');
    is($quux->attr, 'ATTR');
    is($quux->extra, 'ARTXE');
}

{
    my $quux = Quux->new(attr => 'RTTA', extra => 'ARTXE');
    is($quux->attr, 'RTTA');
    is($quux->extra, 'ARTXE');
}

done_testing;
