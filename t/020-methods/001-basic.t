#!perl

use strict;
use warnings;

use Test::More;

use mop;

=pod

This is just a basic test for what we have now,
which is pretty basic and primative. The plan
is to wait to see what happens with the
function signature work and basically use what
they have, only for methods.

Eventually this test (and this test folder) will
get a lot more tests when we know how things end
up.

=cut

class Foo {

    method bar { 'BAR' }

    method bar_w_implicit_params { join ', ' => 'BAR', @_ }

    method bar_w_explicit_params (@args) { join ', ' => 'BAR', @args }

    method bar_w_explicit_param ($a) { join ', ' => 'BAR', ($a // '') }

    method bar_w_default_params ($a = 10) { join ', ' => 'BAR', $a }

}

my $foo = Foo->new;
isa_ok($foo, 'Foo');

is($foo->bar, 'BAR', '... got the expected return value');

is($foo->bar_w_implicit_params, 'BAR', '... got the expected return value');
is($foo->bar_w_implicit_params(1, 2), 'BAR, 1, 2', '... got the expected return value');

is($foo->bar_w_explicit_params, 'BAR', '... got the expected return value');
is($foo->bar_w_explicit_params(1, 2), 'BAR, 1, 2', '... got the expected return value');

{
    # NOTE:
    # We can sit on this one for now and
    # wait until the function sigs is more
    # nailed down.
    # - SL
    local $TODO = '<rjbs> stevan: My recollection was "too few is an error, too many is not," but there is a thread... (but not a spec)...';
    eval { $foo->bar_w_explicit_param; die 'Stupid uninitialized variable warnings, *sigh*' };
    like(
        $@,
        qr/Not enough parameters/,
        '... got the expected error'
    );
}
is($foo->bar_w_explicit_param(1), 'BAR, 1', '... got the expected return value');

is($foo->bar_w_default_params, 'BAR, 10', '... got the expected return value');
is($foo->bar_w_default_params(1), 'BAR, 1', '... got the expected return value');

done_testing;
