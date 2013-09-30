#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

class Foo {
    has $!foo;
    method foo { $!foo }
}

role Bar {
    has $!baz;
    method baz { $!baz }
}

{
    my $meta = mop::meta('Foo');

    my $attr = $meta->get_attribute('$!foo');
    is($attr->associated_meta, $meta, '... got the expected meta object');

    my $meth = $meta->get_method('foo');
    is($meth->associated_meta, $meta, '... got the expected meta object');

    undef $Foo::METACLASS;
    undef $meta;

    is($attr->associated_meta, undef, '... got the lack of an expected meta object');
    is($meth->associated_meta, undef, '... got the lack of an expected meta object');
}

{
    my $meta = mop::meta('Bar');

    my $attr = $meta->get_attribute('$!baz');
    is($attr->associated_meta, $meta, '... got the expected meta object');

    my $meth = $meta->get_method('baz');
    is($meth->associated_meta, $meta, '... got the expected meta object');

    undef $Bar::METACLASS;
    undef $meta;

    is($attr->associated_meta, undef, '... got the lack of an expected meta object');
    is($meth->associated_meta, undef, '... got the lack of an expected meta object');
}

done_testing;
