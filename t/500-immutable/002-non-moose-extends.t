#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class Foo is sealed {
    method foo { 'FOO' }
    method bar { 'BAR' }
}

{
    package Bar;
    use base 'Foo';
    sub bar { 'BAZ' }
}

{
    my $bar = Bar->new;
    is($bar->foo, 'FOO');
    is($bar->bar, 'BAZ');
}

done_testing;
