#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class Foo {
    has $!foo;
    method foo { $!foo }
}

my $Foo = mop::meta('Foo');

{
    my $clone = $Foo->clone(name => 'Bar');
    is_deeply([map { $_->name } $clone->methods], ['foo']);
    is_deeply([map { $_->name } $clone->attributes], ['$!foo']);

    # deep clone
    isnt($clone->get_method('foo'), $Foo->get_method('foo'));
    isnt($clone->get_attribute('$!foo'), $Foo->get_attribute('$!foo'));

    is($clone->get_method('foo')->associated_meta, $clone);
    is($clone->get_attribute('$!foo')->associated_meta, $clone);
    is($Foo->get_method('foo')->associated_meta, $Foo);
    is($Foo->get_attribute('$!foo')->associated_meta, $Foo);

    is($Foo->version, undef);
    is($clone->version, undef);
}

done_testing;
