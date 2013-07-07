#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

role ABC {};
class XYZ {};

ok($INC{'ABC.pm'});
ok($INC{'XYZ.pm'});

done_testing;
