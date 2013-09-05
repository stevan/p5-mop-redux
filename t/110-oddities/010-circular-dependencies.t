#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 't/lib';

eval {
    require Circular;
};
like($@, qr/Circular has already been used as a non-mop class\. Does your code have a circular dependency\?/);

done_testing;
