#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my $Foo = mop::class->new(name => 'Foo');
is($Foo->version, undef);
is($Foo->authority, undef);
is($Foo->superclass, undef);

done_testing;
