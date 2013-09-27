#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my $Foo = mop::class->new;
is($Foo->name, undef);
is($Foo->version, undef);
is($Foo->authority, undef);
is($Foo->superclass, undef);

done_testing;
