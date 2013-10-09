##!/usr/bin/perl

use strict;
use warnings;
use lib 't/lib';

use Test::More;

=pod

This came up when I was porting Plack to
use the mop. The second package declaration
My::Test::Foo will (sorta) stomp on the
namespace created by the class Foo that
is defined in the first package My::Test;

When the mop is imported into My::Test::Foo
it will create a local sub called method that
will override the method 'method' in
the My::Test::Foo class.

This test just makes sure that the namespaces
are getting cleaned out properly.

=cut

{
    package My::Test;
    use strict;
    use warnings;
    use mop;

    class Foo {
        method method { "calling the method method" }
    }

    no mop; # need to this cause our UNITCHECK won't fire
}

{
    package My::Test::Foo;
    use strict;
    use warnings;
    use mop;

    class Bar {
        method foo { 10 }
    }

    no mop; # need to this cause our UNITCHECK won't fire
}

my $foo = My::Test::Foo->new;
isa_ok($foo, 'My::Test::Foo');

is($foo->method, 'calling the method method', '... methods named method work if you unexport');

require BB::ConstructorInjection;
require BB::ConstructorInjection::Singleton;

my $bar = BB::ConstructorInjection->new;
isa_ok($bar, 'BB::ConstructorInjection');

is($bar->method, 'calling the method method', '... methods named method work if you unexport');

done_testing;
