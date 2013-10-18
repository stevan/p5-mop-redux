#!/usr/bin/env perl
use strict;
use warnings;
use lib 't/lib';
use Test::More;

use mop;

class ClassBefore { }
role RoleBefore { }

{

    use mop
        class_metaclass => 'Custom::Class',
        role_metaclass  => 'Custom::Role';

    class ClassInside { }
    role RoleInside { }
}

class ClassAfter { }
role RoleAfter { }

is(ref(mop::meta('ClassBefore')), 'mop::class');
is(ref(mop::meta('RoleBefore')), 'mop::role');

isa_ok(mop::meta('ClassInside'), 'Custom::Class');
isa_ok(mop::meta('RoleInside'), 'Custom::Role');

is(ref(mop::meta('ClassAfter')), 'mop::class');
is(ref(mop::meta('RoleAfter')), 'mop::role');

done_testing;
