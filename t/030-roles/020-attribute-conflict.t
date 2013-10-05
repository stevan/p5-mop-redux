#!perl

use strict;
use warnings;

use Test::More;

use mop;

role Foo {
    has $!foo;
}

{
    eval q[
        role Foo2 with Foo {
            has $!foo;
        }
    ];
    like("$@", qr/Attribute conflict \$!foo/, '... got the expected error message (role on role)');
    $@ = undef;
}

role Bar {
    has $!foo;
}

{
    eval q[
        role FooBar with Foo, Bar {}
    ];
    like("$@", qr/Attribute conflict \$!foo/, '... got the expected error message (composite role)');
    $@ = undef;
}


{
    eval q[
        class FooBaz with Foo {
            has $!foo;
        }
    ];
    like("$@", qr/Attribute conflict \$!foo/, '... got the expected error message (role on class)');
    $@ = undef;
}

done_testing;
