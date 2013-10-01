#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class MyMeta extends mop::class {
    method foo { 'MyMeta' }
}

sub mymeta {
    mop::apply_metaclass($_[0], 'MyMeta');
}

class Foo is mymeta { }

isa_ok(mop::meta('Foo'), 'MyMeta');

class MyOtherMeta extends mop::class {
    method foo { 'MyOtherMeta' }
}

sub myothermeta {
    mop::apply_metaclass($_[0], 'MyOtherMeta');
}

eval "
class Bar extends Foo is myothermeta { }
";
like($@, qr/compatib/);

done_testing;
