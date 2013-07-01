#!perl

use strict;
use warnings;

use Test::More;

use mop ();

ok(mop::object->metaclass->isa('mop::class'), '... object->class is instance of class');
ok(mop::class->isa('mop::object'), '... class isa object');
ok(mop::class->metaclass->isa('mop::class'), '... class->class is instance of class');

isa_ok('mop::method', 'mop::object');
isa_ok('mop::attribute', 'mop::object');

is_deeply(
    mop::mro::get_linear_isa('mop::class'),
    [ 'mop::class', 'mop::role', 'mop::object' ],
    '... got the expected mro'
);

is_deeply(
    mop::mro::get_linear_isa('mop::method'),
    [ 'mop::method', 'mop::object' ],
    '... got the expected mro'
);

is_deeply(
    mop::mro::get_linear_isa('mop::attribute'),
    [ 'mop::attribute', 'mop::object' ],
    '... got the expected mro'
);

is_deeply(
    mop::mro::get_linear_isa('mop::object'),
    [ 'mop::object' ],
    '... got the expected mro'
);


done_testing;