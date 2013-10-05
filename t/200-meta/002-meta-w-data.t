#!perl

use strict;
use warnings;
use 5.016;

use Test::More;

use mop;

# create a meta-class (class to create classes with)
role WithData {

    has $!data = [];

    method get_data { $!data }

    method add_to_data ($value) {
        push @{$!data} => $value;
    }
}

sub data {
    my ($meta, @data) = @_;
    if (!$meta->does('WithData')) {
        my $class = mop::meta($meta);
        my $new_subclass = mop::meta($class)->new_instance(
            name       => sprintf("mop::instance_application::%d", ++state($i)),
            superclass => $class->name,
            roles      => [ mop::meta('WithData') ],
        );
        $new_subclass->FINALIZE;

        mop::rebless $meta, $new_subclass->name;
    }
    $meta->add_to_data($_) for @data;
}

# create a class (using our meta-class)
class Foo is data {
    method get_meta_data {
        mop::meta($self)->get_data
    }
}

# create a class (using our meta-class and extra data)
class Bar is data(1, 2, 3) {
    method get_meta_data {
        mop::meta($self)->get_data
    }
}

ok(mop::meta('Foo')->isa( 'mop::object' ), '... Foo is an Object');
ok(mop::meta('Foo')->isa( 'mop::class' ), '... Foo is a Class');
ok(mop::meta('Foo')->does( 'WithData' ), '... Foo does WithData');

is_deeply(mop::meta('Foo')->get_data, [], '... called the static method on Foo');

ok(mop::meta('Bar')->isa( 'mop::object' ), '... Bar is an Object');
ok(mop::meta('Bar')->isa( 'mop::class' ), '... Bar is a Class');
ok(mop::meta('Bar')->does( 'WithData' ), '... Bar does WithData');

is_deeply(mop::meta('Bar')->get_data, [ 1, 2, 3 ], '... called the static method on Bar');

isnt(mop::meta('Foo')->get_data, mop::meta('Bar')->get_data, '... the two classes share a different class level data');

{
    my $foo = Foo->new;
    ok($foo->isa( 'Foo' ), '... got an instance of Foo');
    is_deeply($foo->get_meta_data, [], '... got the expected foo metadata');
    is($foo->get_meta_data, mop::meta('Foo')->get_data, '... and it matches the metadata for Foo');

    my $foo2 = Foo->new;
    ok($foo2->isa( 'Foo' ), '... got an instance of Foo');
    is_deeply($foo2->get_meta_data, [], '... got the expected foo metadata');
    is($foo2->get_meta_data, mop::meta('Foo')->get_data, '... and it matches the metadata for Foo');
    is($foo2->get_meta_data, $foo->get_meta_data, '... and it is shared across instances');

    mop::meta('Foo')->add_to_data( 10 );
    is_deeply(mop::meta('Foo')->get_data, [ 10 ], '... got the expected (changed) Foo metadata');

    is_deeply($foo->get_meta_data, [ 10 ], '... got the expected (changed) foo metadata');
    is_deeply($foo2->get_meta_data, [ 10 ], '... got the expected (changed) foo metadata');

    is($foo->get_meta_data, mop::meta('Foo')->get_data, '... and it matches the metadata for Foo still');
    is($foo2->get_meta_data, mop::meta('Foo')->get_data, '... and it matches the metadata for Foo still');
    is($foo2->get_meta_data, $foo->get_meta_data, '... and it is shared across instances still');
}

{
    my $bar = Bar->new;
    ok($bar->isa( 'Bar' ), '... got an instance of Bar');
    is_deeply($bar->get_meta_data, [ 1, 2, 3 ], '... got the expected bar metadata');
    is($bar->get_meta_data, mop::meta('Bar')->get_data, '... and it matches the metadata for Bar');

    my $bar2 = Bar->new;
    ok($bar2->isa( 'Bar' ), '... got an instance of Bar');
    is_deeply($bar2->get_meta_data, [1, 2, 3], '... got the expected bar metadata');
    is($bar2->get_meta_data, mop::meta('Bar')->get_data, '... and it matches the metadata for Bar');
    is($bar2->get_meta_data, $bar->get_meta_data, '... and it is shared across instances');

    mop::meta('Bar')->add_to_data( 10 );
    is_deeply(mop::meta('Bar')->get_data, [ 1, 2, 3, 10 ], '... got the expected (changed) Bar metadata');

    is_deeply($bar->get_meta_data, [ 1, 2, 3, 10 ], '... got the expected (changed) bar metadata');
    is_deeply($bar2->get_meta_data, [ 1, 2, 3, 10 ], '... got the expected (changed) bar metadata');

    is($bar->get_meta_data, mop::meta('Bar')->get_data, '... and it matches the metadata for Bar still');
    is($bar2->get_meta_data, mop::meta('Bar')->get_data, '... and it matches the metadata for Bar still');
    is($bar2->get_meta_data, $bar->get_meta_data, '... and it is shared across instances still');

    is_deeply(mop::meta('Foo')->get_data, [ 10 ], '... got the expected (unchanged) Foo metadata');
}

done_testing;
