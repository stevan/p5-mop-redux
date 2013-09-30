#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use 5.016;

use mop;

class Foo {
    method foo { __CLASS__ }
    method bar { __CLASS__ }
}

role Bar {
    method foo { __ROLE__ }
    method baz { __ROLE__ }
}

my $foo = Foo->new;
is($foo->foo, 'Foo');
is($foo->bar, 'Foo');
ok(!$foo->can('baz'));

apply_role_to_instance($foo, 'Bar');
is($foo->foo, 'Bar');
is($foo->bar, 'Foo');
is($foo->baz, 'Bar');

sub apply_role_to_instance {
    my ($instance, $role) = @_;

    $role = mop::meta($role) unless ref $role;

    my $class = mop::meta($instance);
    my $new_subclass = mop::meta($class)->new_instance(
        name       => sprintf("mop::instance_application::%d", ++state($i)),
        superclass => $class->name,
        roles      => [ $role ],
    );
    $new_subclass->FINALIZE;

    mop::rebless $instance, $new_subclass->name;
}

done_testing;
