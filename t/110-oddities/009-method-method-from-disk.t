##!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use FindBin;
use lib "$FindBin::Bin/../lib";

=pod

This test is a clone of 008-method-method.t
but testing that it works when loading from
disk (and doesn't need the C<no mop> at the
end of the package definition).

=cut

use My::Test;
use My::Test::Foo;

my $foo = My::Test::Foo->new;
isa_ok($foo, 'My::Test::Foo');

is($foo->method, 'calling the method method', '... methods named method work if you unexport');

done_testing;
