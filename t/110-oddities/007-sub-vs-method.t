##!/usr/bin/perl

use strict;
use warnings;

use Test::More;

{

    package My::Test;
    use strict;
    use warnings;
    use mop;

    sub foo { 'My::Test::foo' }

    class Foo {
        method foo { "calling " . foo() }
    }
}

my $foo = My::Test::Foo->new;
isa_ok($foo, 'My::Test::Foo');

is($foo->foo, 'calling My::Test::foo', '... methods and subs dont clash');

done_testing;
