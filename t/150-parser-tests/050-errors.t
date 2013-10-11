#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

eval '
class Foo {
    has $!foo bar;
}
';
like($@, qr/^Couldn't parse attribute \$!foo/);

eval '
class Bar:Bar { }
';
like($@, qr/^Invalid identifier: Bar:Bar/);

done_testing;
