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

    $role = mop::get_meta($role) unless ref $role;

    my $class = mop::get_meta($instance);
    my $new_subclass = ref(mop::get_meta($class))->new(
        name       => sprintf("mop::instance_application::%d", ++state($i)),
        superclass => $class->name,
        roles      => [ $role ],
    );
    # hopefully these two steps can be implicit in the future? or something?
    mop::util::install_meta($new_subclass);
    $new_subclass->FINALIZE;

    mop::util::rebless $instance, $new_subclass->name;
}

done_testing;
