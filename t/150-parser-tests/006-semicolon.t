#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

eval '
class Foo { has $!foo }
';
is($@, '');

eval '
role Bar { method bar }
';
is($@, '');

done_testing;
