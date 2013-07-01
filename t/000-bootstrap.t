#!perl

use strict;
use warnings;

use Test::More;

use mop ();

# make sure to bootstrap things ...
# this is only needed because we 
# do `use mop ()` with the parens
# afterwards.
mop::bootstrap; 

ok(mop::object->metaclass->isa('mop::class'), '... object->class is instance of class');
ok(mop::class->isa('mop::object'), '... class isa object');
ok(mop::class->metaclass->isa('mop::class'), '... class->class is instance of class');

ok(mop::attribute->isa('mop::object'), '... attribute isa object');
ok(mop::attribute->metaclass->isa('mop::class'), '... attribute->class is instance of class');

ok(mop::method->isa('mop::object'), '... method isa object');
ok(mop::method->metaclass->isa('mop::class'), '... method->class is instance of class');

isa_ok('mop::method', 'mop::object');
isa_ok('mop::attribute', 'mop::object');

is_deeply(
    mop::mro::get_linear_isa('mop::class'),
    [ 'mop::class', 'mop::object' ],
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

{
    my $class = mop::class->metaclass;
    my $role  = mop::role->metaclass;

    ok($class->does_role('mop::role'), '... class does role');
    ok($role->isa('mop::class'), '... class does role');
    ok($role->does('mop::role'), '... role does role');

    ok($class->has_method('name'), '... mop::class does have the name method that was composed into it');
}





done_testing;