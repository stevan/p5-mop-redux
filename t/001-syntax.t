#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

BEGIN {
    class Bar {
        method baz { 'Foo::Bar::baz' }
    }
}

diag(Bar->baz);

done_testing;