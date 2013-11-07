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

eval '
class Bar { has $! is rw }
';
like($@, qr/^\$\! is not a valid attribute name/);

eval '
class Bar { has $!1 is rw }
';
like($@, qr/^\$\!1 is not a valid attribute name/);

eval '
class Bar { has $!x is "bah" }
';
like($@, qr/^"bah" is not a valid trait name/);

eval '
class Bar { method cat($4) { } }
';
like($@, qr/^\$4 is not a valid argument name/);

eval '
    has $!x
';
like($@, qr/^has must be called from within a class or role block/, '\'has...\' outside of Class has a good error');

eval '
    method foo { }
';
like($@, qr/^method must be called from within a class or role block/, '\'method...\' outside of Class has a good error');

eval '
class Baz {
    method {}
}
';
like($@, qr/^No method name found/, "syntax errors in class blocks are propagated properly");

done_testing;
