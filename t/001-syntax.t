#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

class Bar {
    method baz { 'Bar::baz' }
}

is(Bar->baz, 'Bar::baz', '... simple test works');

done_testing;