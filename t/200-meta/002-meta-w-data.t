#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

# create a meta-class (class to create classes with)
class MetaWithData (extends => 'mop::class') {

    has $data = [];

    method get_data { $data }

    method add_to_data ($value) {
        push @$data => $value;
    }
}

# create a class (using our meta-class)
class Foo (metaclass => 'MetaWithData') {
    method get_meta_data {
        ${^CLASS}->get_data
    }
}

# create a class (using our meta-class and extra data)
class Bar (metaclass => 'MetaWithData', data => [ 1, 2, 3 ]) {
    method get_meta_data {
        ${^CLASS}->get_data
    }
}

ok(MetaWithData->isa( 'mop::object' ), '... MetaWithData is an Object');
ok(MetaWithData->isa( 'mop::class' ), '... MetaWithData is a Class');

ok(Foo->metaclass->isa( 'mop::object' ), '... Foo is an Object');
ok(Foo->metaclass->isa( 'mop::class' ), '... Foo is a Class');
ok(Foo->metaclass->isa( 'MetaWithData' ), '... Foo is a MetaWithData');

is_deeply(Foo->metaclass->get_data, [], '... called the static method on Foo');

ok(Bar->metaclass->isa( 'mop::object' ), '... Bar is an Object');
ok(Bar->metaclass->isa( 'mop::class' ), '... Bar is a Class');
ok(Bar->metaclass->isa( 'MetaWithData' ), '... Bar is a MetaWithData');

is_deeply(Bar->metaclass->get_data, [ 1, 2, 3 ], '... called the static method on Bar');

isnt(Foo->metaclass->get_data, Bar->metaclass->get_data, '... the two classes share a different class level data');

{
    my $foo = Foo->new;
    ok($foo->isa( 'Foo' ), '... got an instance of Foo');
    is_deeply($foo->get_meta_data, [], '... got the expected foo metadata');
    is($foo->get_meta_data, Foo->metaclass->get_data, '... and it matches the metadata for Foo');

    my $foo2 = Foo->new;
    ok($foo2->isa( 'Foo' ), '... got an instance of Foo');
    is_deeply($foo2->get_meta_data, [], '... got the expected foo metadata');
    is($foo2->get_meta_data, Foo->metaclass->get_data, '... and it matches the metadata for Foo');
    is($foo2->get_meta_data, $foo->get_meta_data, '... and it is shared across instances');

    Foo->metaclass->add_to_data( 10 );
    is_deeply(Foo->metaclass->get_data, [ 10 ], '... got the expected (changed) Foo metadata');

    is_deeply($foo->get_meta_data, [ 10 ], '... got the expected (changed) foo metadata');
    is_deeply($foo2->get_meta_data, [ 10 ], '... got the expected (changed) foo metadata');

    is($foo->get_meta_data, Foo->metaclass->get_data, '... and it matches the metadata for Foo still');
    is($foo2->get_meta_data, Foo->metaclass->get_data, '... and it matches the metadata for Foo still');
    is($foo2->get_meta_data, $foo->get_meta_data, '... and it is shared across instances still');
}

{
    my $bar = Bar->new;
    ok($bar->isa( 'Bar' ), '... got an instance of Bar');
    is_deeply($bar->get_meta_data, [ 1, 2, 3 ], '... got the expected bar metadata');
    is($bar->get_meta_data, Bar->metaclass->get_data, '... and it matches the metadata for Bar');

    my $bar2 = Bar->new;
    ok($bar2->isa( 'Bar' ), '... got an instance of Bar');
    is_deeply($bar2->get_meta_data, [1, 2, 3], '... got the expected bar metadata');
    is($bar2->get_meta_data, Bar->metaclass->get_data, '... and it matches the metadata for Bar');
    is($bar2->get_meta_data, $bar->get_meta_data, '... and it is shared across instances');

    Bar->metaclass->add_to_data( 10 );
    is_deeply(Bar->metaclass->get_data, [ 1, 2, 3, 10 ], '... got the expected (changed) Bar metadata');

    is_deeply($bar->get_meta_data, [ 1, 2, 3, 10 ], '... got the expected (changed) bar metadata');
    is_deeply($bar2->get_meta_data, [ 1, 2, 3, 10 ], '... got the expected (changed) bar metadata');

    is($bar->get_meta_data, Bar->metaclass->get_data, '... and it matches the metadata for Bar still');
    is($bar2->get_meta_data, Bar->metaclass->get_data, '... and it matches the metadata for Bar still');
    is($bar2->get_meta_data, $bar->get_meta_data, '... and it is shared across instances still');

    is_deeply(Foo->metaclass->get_data, [ 10 ], '... got the expected (unchanged) Foo metadata');
}

done_testing;