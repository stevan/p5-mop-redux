#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

# create a meta-class (class to create classes with)
class MetaWithData extends mop::class {

    has $data = [];

    method get_data { $data }

    method add_to_data ($value) {
        push @$data => $value;
    }
}

# XXX eventually, the trait should handle applying the metaclass itself, but that requires mop-level reblessing and/or role application to instances
sub data {
    my ($meta, @data) = @_;
    $meta->add_to_data($_) for @data;
}

# create a class (using our meta-class)
class Foo metaclass MetaWithData {
    method get_meta_data {
        mop::get_meta($self)->get_data
    }
}

# create a class (using our meta-class and extra data)
class Bar metaclass MetaWithData is data(1, 2, 3) {
    method get_meta_data {
        mop::get_meta($self)->get_data
    }
}

ok(MetaWithData->isa( 'mop::object' ), '... MetaWithData is an Object');
ok(MetaWithData->isa( 'mop::class' ), '... MetaWithData is a Class');

ok(mop::get_meta('Foo')->isa( 'mop::object' ), '... Foo is an Object');
ok(mop::get_meta('Foo')->isa( 'mop::class' ), '... Foo is a Class');
ok(mop::get_meta('Foo')->isa( 'MetaWithData' ), '... Foo is a MetaWithData');

is_deeply(mop::get_meta('Foo')->get_data, [], '... called the static method on Foo');

ok(mop::get_meta('Bar')->isa( 'mop::object' ), '... Bar is an Object');
ok(mop::get_meta('Bar')->isa( 'mop::class' ), '... Bar is a Class');
ok(mop::get_meta('Bar')->isa( 'MetaWithData' ), '... Bar is a MetaWithData');

is_deeply(mop::get_meta('Bar')->get_data, [ 1, 2, 3 ], '... called the static method on Bar');

isnt(mop::get_meta('Foo')->get_data, mop::get_meta('Bar')->get_data, '... the two classes share a different class level data');

{
    my $foo = Foo->new;
    ok($foo->isa( 'Foo' ), '... got an instance of Foo');
    is_deeply($foo->get_meta_data, [], '... got the expected foo metadata');
    is($foo->get_meta_data, mop::get_meta('Foo')->get_data, '... and it matches the metadata for Foo');

    my $foo2 = Foo->new;
    ok($foo2->isa( 'Foo' ), '... got an instance of Foo');
    is_deeply($foo2->get_meta_data, [], '... got the expected foo metadata');
    is($foo2->get_meta_data, mop::get_meta('Foo')->get_data, '... and it matches the metadata for Foo');
    is($foo2->get_meta_data, $foo->get_meta_data, '... and it is shared across instances');

    mop::get_meta('Foo')->add_to_data( 10 );
    is_deeply(mop::get_meta('Foo')->get_data, [ 10 ], '... got the expected (changed) Foo metadata');

    is_deeply($foo->get_meta_data, [ 10 ], '... got the expected (changed) foo metadata');
    is_deeply($foo2->get_meta_data, [ 10 ], '... got the expected (changed) foo metadata');

    is($foo->get_meta_data, mop::get_meta('Foo')->get_data, '... and it matches the metadata for Foo still');
    is($foo2->get_meta_data, mop::get_meta('Foo')->get_data, '... and it matches the metadata for Foo still');
    is($foo2->get_meta_data, $foo->get_meta_data, '... and it is shared across instances still');
}

{
    my $bar = Bar->new;
    ok($bar->isa( 'Bar' ), '... got an instance of Bar');
    is_deeply($bar->get_meta_data, [ 1, 2, 3 ], '... got the expected bar metadata');
    is($bar->get_meta_data, mop::get_meta('Bar')->get_data, '... and it matches the metadata for Bar');

    my $bar2 = Bar->new;
    ok($bar2->isa( 'Bar' ), '... got an instance of Bar');
    is_deeply($bar2->get_meta_data, [1, 2, 3], '... got the expected bar metadata');
    is($bar2->get_meta_data, mop::get_meta('Bar')->get_data, '... and it matches the metadata for Bar');
    is($bar2->get_meta_data, $bar->get_meta_data, '... and it is shared across instances');

    mop::get_meta('Bar')->add_to_data( 10 );
    is_deeply(mop::get_meta('Bar')->get_data, [ 1, 2, 3, 10 ], '... got the expected (changed) Bar metadata');

    is_deeply($bar->get_meta_data, [ 1, 2, 3, 10 ], '... got the expected (changed) bar metadata');
    is_deeply($bar2->get_meta_data, [ 1, 2, 3, 10 ], '... got the expected (changed) bar metadata');

    is($bar->get_meta_data, mop::get_meta('Bar')->get_data, '... and it matches the metadata for Bar still');
    is($bar2->get_meta_data, mop::get_meta('Bar')->get_data, '... and it matches the metadata for Bar still');
    is($bar2->get_meta_data, $bar->get_meta_data, '... and it is shared across instances still');

    is_deeply(mop::get_meta('Foo')->get_data, [ 10 ], '... got the expected (unchanged) Foo metadata');
}

done_testing;