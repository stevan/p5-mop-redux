#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

eval '
class 1Foo {}
';
like($@, qr/1Foo is not a valid class name/);

eval '
class Bar::1Baz {}
';
is($@, '');
isa_ok(Bar::1Baz->new, 'Bar::1Baz');

done_testing;
