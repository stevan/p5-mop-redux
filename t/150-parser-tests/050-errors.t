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

TODO: {
    local $TODO = "has ... outside of class {} throws weird error";

    eval '
        has $!x
    ';
    unlike($@, qr/Can't call method "attribute_class" on an undefined value/, '\'has...\' outside of Class has a good error');
}

done_testing;
