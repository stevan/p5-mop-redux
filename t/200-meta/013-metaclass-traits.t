#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class MyMeta extends mop::class {
    method foo { 'MyMeta' }
}

sub mymeta {
    bless $_[0], 'MyMeta';
}

class Foo is mymeta { }

isa_ok(mop::get_meta('Foo'), 'MyMeta');

class MyOtherMeta extends mop::class {
    method foo { 'MyOtherMeta' }
}

sub myothermeta {
    # what's the right thing to do here?
    bless $_[0], 'MyOtherMeta';
}

{ $TODO = "not sure how to make this work";
eval "
class Bar extends Foo is myothermeta { }
";
like($@, qr/compatible/);
}

done_testing;
