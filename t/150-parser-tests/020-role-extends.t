#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class Bar { }

eval "role Foo extends Bar { }";
like($@, qr/Roles cannot use 'extends'/);

done_testing;
