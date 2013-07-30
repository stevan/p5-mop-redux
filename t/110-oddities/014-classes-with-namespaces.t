#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

{
    package My::Foo;
    use strict;
    use warnings;
    use mop;

    class Bar {
        method bar { My::Foo::Baz::Gorch->new }
    }

    class Baz::Gorch {}
}

my $bar = My::Foo::Bar->new;
isa_ok($bar, 'My::Foo::Bar');

my $result;
is(exception{ $result = $bar->bar }, undef, '... worked successfully');
isa_ok($result, 'My::Foo::Baz::Gorch');

done_testing;