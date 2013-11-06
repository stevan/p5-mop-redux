#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

sub mytrait { }

eval '
class Foo {
    method foo is mytrait ("a") { }
}
';
is($@, '');

done_testing;
