#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

eval '
class 1Foo {}
';
like($@, qr/1Foo is not a valid class name/);

done_testing;
