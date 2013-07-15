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

ok(mop::get_meta('mop::object')->isa('mop::class'), '... object->class is instance of class');
ok(mop::class->isa('mop::object'), '... class isa object');
ok(mop::get_meta('mop::class')->isa('mop::class'), '... class->class is instance of class');

ok(mop::attribute->isa('mop::object'), '... attribute isa object');
ok(mop::get_meta('mop::attribute')->isa('mop::class'), '... attribute->class is instance of class');

ok(mop::method->isa('mop::object'), '... method isa object');
ok(mop::get_meta('mop::method')->isa('mop::class'), '... method->class is instance of class');

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
    my $class  = mop::get_meta('mop::class');
    my $object = mop::get_meta('mop::object');
    my $role   = mop::get_meta('mop::role');

    ok($class->isa('mop::class'), '... class is an instance of class');
    ok($object->isa('mop::class'), '... object is an instance of class');
    ok($class->isa('mop::object'), '... class is a subclass of object');

    ok($class->does_role('mop::role'), '... class does role');
    ok($role->isa('mop::class'), '... role is an instance of class');
    ok($role->does('mop::role'), '... role does role');

    ok($class->has_method('name'), '... mop::class does have the name method that was composed into it');
}





done_testing;