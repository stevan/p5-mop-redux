#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my ($foo, $bar);
class Foo {
    method foo {
        $foo++;
    }
}

role Bar {
    method foo {
        $self->next::method(@_);
        $bar++;
    }
}

class Baz extends Foo with Bar { }

{
    my $baz = Baz->new;
    ($foo, $bar) = (0, 0);
    $baz->foo;
    is($foo, 1);
    is($bar, 1);
}

done_testing;
