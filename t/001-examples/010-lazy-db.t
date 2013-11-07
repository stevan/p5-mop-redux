#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::PP;
my $JSON = JSON::PP->new->ascii->canonical;

use mop;

class MyObjectDB::Thunk {
    has $!db is required;
    has $!id is required;

    method force {
        return $!db->lookup($!id);
    }
}

role MyObjectDB::Lazy {
    method get_slot_for ($obj) {
        my $slot = $self->next::method($obj);
        if (ref($$slot) eq 'MyObjectDB::Thunk') {
            $$slot = $$slot->force;
        }
        return $slot;
    }
}

sub db_lazy {
    my ($attr) = @_;
    mop::apply_metarole($attr, 'MyObjectDB::Lazy');
}

# handling cyclic graphs is left as an exercise for the reader
class MyObjectDB {
    # pretend this is actually talking to an external database
    has $!backend = {};

    method lookup ($id) {
        my $json = $!backend->{$id};
        return unless $json;
        my $data = $JSON->decode($json);
        my $obj;
        if (defined $data->{class}) {
            my $class = mop::meta($data->{class});

            $obj = $class->new_fresh_instance;

            for my $attr (keys %{ $data->{instance} }) {
                my ($type, $value) = @{ $data->{instance}{$attr} };
                if ($type eq 'ref') {
                    $value = $self->lookup($value);
                }
                elsif ($type eq 'thunk') {
                    $value = MyObjectDB::Thunk->new(db => $self, id => $value);
                }
                elsif ($type ne 'val') {
                    die "unknown type $type";
                }
                my $slot = $class->get_attribute($attr)->get_slot_for($obj);
                $$slot = $value;
            }
        }
        else {
            $obj = $data->{instance};
        }

        return $obj;
    }

    method insert ($id, $obj) {
        my $data;
        if (mop::meta($obj)) {
            $data = $self->_instance_data($obj);
        }
        elsif (ref($obj)) {
            $data = { instance => $obj };
        }
        else {
            die "Can only store references, not $obj";
        }

        $data->{id} = $id;

        $!backend->{$id} = $JSON->encode($data);
    }

    method _instance_data ($obj) {
        my $class = mop::meta($obj);
        my $data = {
            class    => $class->name,
            instance => {
                map {
                    my $attr = $_;
                    my $slot = $attr->get_slot_for($obj);
                    if (my $val = $$slot) {
                        if (ref($val)) {
                            my $id = mop::id($val) // 0+$val;
                            $self->insert($id, $val);
                            if ($attr->does('MyObjectDB::Lazy')) {
                                ($attr->name => [ 'thunk' => $id ])
                            }
                            else {
                                ($attr->name => [ 'ref' => $id ])
                            }
                        }
                        else {
                            ($attr->name => [ 'val' => $val ])
                        }
                    }
                    else {
                        ()
                    }
                } $class->attributes
            },
        };
    }
}

class Foo {
    has $!bar is ro;
    has $!baz is lazy, ro = Baz->new;
}

my $i = 1;
class Baz {
    has $!hash is ro = { i => $i++ };
}

{
    my $db = MyObjectDB->new;

    my ($baz_id, $baz_hash_id);
    {
        my $foo = Foo->new(bar => 42);
        $db->insert(foo1 => $foo);
    }

    {
        my $foo = Foo->new(bar => 'BAR');
        $baz_id = mop::id($foo->baz);
        $baz_hash_id = 0+$foo->baz->hash;
        $db->insert(foo2 => $foo);
    }

    {
        my $foo = $db->lookup('foo1');
        is_deeply(
            mop::dump_object($foo),
            {
                __CLASS__ => 'Foo',
                __ID__    => mop::id($foo),
                __SELF__  => $foo,
                '$!bar'   => 42,
                '$!baz'   => undef,
            }
        );
    }

    {
        my $foo = $db->lookup('foo2');
        my $dump = mop::dump_object($foo);
        my $baz = delete $dump->{'$!baz'}{__SELF__};
        is($baz, ${ mop::meta('Foo')->get_attribute('$!baz')->get_slot_for($foo) });
        is(delete $dump->{'$!baz'}{__ID__}, mop::id($baz));
        is_deeply(
            $dump,
            {
                __CLASS__    => 'Foo',
                __ID__       => mop::id($foo),
                __SELF__     => $foo,
                '$!bar' => 'BAR',
                '$!baz' => {
                    __CLASS__ => 'Baz',
                    '$!hash' => { i => 1 },
                },
            }
        );
    }

    is_deeply(
        mop::meta('MyObjectDB')->get_attribute('$!backend')->fetch_data_in_slot_for($db),
        {
            foo1 => '{"class":"Foo","id":"foo1","instance":{"$!bar":["val",42]}}',
            foo2 => '{"class":"Foo","id":"foo2","instance":{"$!bar":["val","BAR"],"$!baz":["ref","' . $baz_id . '"]}}',
            $baz_id => '{"class":"Baz","id":"' . $baz_id . '","instance":{"$!hash":["ref",' . $baz_hash_id . ']}}',
            $baz_hash_id => '{"id":' . $baz_hash_id . ',"instance":{"i":1}}',
        }
    );
}

class LazyFoo {
    has $!bar is ro;
    has $!baz is lazy, db_lazy, ro = Baz->new;
}

class MyObjectDB::TraceLookups extends MyObjectDB {
    has $!lookups is rw = [];
    method lookup ($id) {
        push @{ $!lookups }, $id;
        $self->next::method($id);
    }
}

{
    my $db = MyObjectDB::TraceLookups->new;

    my ($baz_id, $baz_hash_id);
    {
        my $foo = LazyFoo->new(bar => 42);
        $db->insert(foo1 => $foo);
    }

    {
        my $foo = LazyFoo->new(bar => 'BAR');
        $baz_id = mop::id($foo->baz);
        $baz_hash_id = 0+$foo->baz->hash;
        $db->insert(foo2 => $foo);
    }

    {
        my $foo = $db->lookup('foo1');
        is_deeply(
            mop::dump_object($foo),
            {
                __CLASS__ => 'LazyFoo',
                __ID__    => mop::id($foo),
                __SELF__  => $foo,
                '$!bar'   => 42,
                '$!baz'   => undef,
            }
        );
    }

    {
        my $foo = $db->lookup('foo2');
        my $dump = mop::dump_object($foo);
        my $baz = delete $dump->{'$!baz'}{__SELF__};
        is($baz, ${ mop::meta('LazyFoo')->get_attribute('$!baz')->get_slot_for($foo) });
        is(delete $dump->{'$!baz'}{__ID__}, mop::id($baz));
        is_deeply(
            $dump,
            {
                __CLASS__    => 'LazyFoo',
                __ID__       => mop::id($foo),
                __SELF__     => $foo,
                '$!bar' => 'BAR',
                '$!baz' => {
                    __CLASS__ => 'Baz',
                    '$!hash' => { i => 2 },
                },
            }
        );
    }

    is_deeply(
        mop::meta('MyObjectDB')->get_attribute('$!backend')->fetch_data_in_slot_for($db),
        {
            foo1 => '{"class":"LazyFoo","id":"foo1","instance":{"$!bar":["val",42]}}',
            foo2 => '{"class":"LazyFoo","id":"foo2","instance":{"$!bar":["val","BAR"],"$!baz":["thunk","' . $baz_id . '"]}}',
            $baz_id => '{"class":"Baz","id":"' . $baz_id . '","instance":{"$!hash":["ref",' . $baz_hash_id . ']}}',
            $baz_hash_id => '{"id":' . $baz_hash_id . ',"instance":{"i":2}}',
        }
    );
}

{
    my $db = MyObjectDB::TraceLookups->new;

    my ($eager_baz_id, $lazy_baz_id, $eager_baz_hash_id, $lazy_baz_hash_id);
    {
        my $foo = Foo->new;
        $eager_baz_id = mop::id($foo->baz);
        $eager_baz_hash_id = 0+$foo->baz->hash;
        $db->insert(eager_foo => $foo);
    }

    {
        my $foo = LazyFoo->new;
        $lazy_baz_id = mop::id($foo->baz);
        $lazy_baz_hash_id = 0+$foo->baz->hash;
        $db->insert(lazy_foo => $foo);
    }

    {
        $db->lookups([]);
        my $foo = $db->lookup('eager_foo');
        is_deeply($db->lookups, ['eager_foo', $eager_baz_id, $eager_baz_hash_id]);
        my $dump = mop::dump_object($foo);
        my $baz = delete $dump->{'$!baz'}{__SELF__};
        isa_ok($baz, 'Baz');
        is(delete $dump->{'$!baz'}{__ID__}, mop::id($baz));
        is_deeply(
            $dump,
            {
                __CLASS__    => 'Foo',
                __ID__       => mop::id($foo),
                __SELF__     => $foo,
                '$!bar' => undef,
                '$!baz' => {
                    __CLASS__ => 'Baz',
                    '$!hash' => { i => 3 },
                },
            }
        );
        is_deeply($db->lookups, ['eager_foo', $eager_baz_id, $eager_baz_hash_id]);
    }

    {
        $db->lookups([]);
        my $foo = $db->lookup('lazy_foo');
        is_deeply($db->lookups, ['lazy_foo']);
        my $dump = mop::dump_object($foo);
        my $baz = delete $dump->{'$!baz'}{__SELF__};
        isa_ok($baz, 'Baz');
        is(delete $dump->{'$!baz'}{__ID__}, mop::id($baz));
        is_deeply(
            $dump,
            {
                __CLASS__    => 'LazyFoo',
                __ID__       => mop::id($foo),
                __SELF__     => $foo,
                '$!bar' => undef,
                '$!baz' => {
                    __CLASS__ => 'Baz',
                    '$!hash' => { i => 4 },
                },
            }
        );
        is_deeply($db->lookups, ['lazy_foo', $lazy_baz_id, $lazy_baz_hash_id]);
    }

    is_deeply(
        mop::meta('MyObjectDB')->get_attribute('$!backend')->fetch_data_in_slot_for($db),
        {
            eager_foo => '{"class":"Foo","id":"eager_foo","instance":{"$!baz":["ref","' . $eager_baz_id . '"]}}',
            lazy_foo => '{"class":"LazyFoo","id":"lazy_foo","instance":{"$!baz":["thunk","' . $lazy_baz_id . '"]}}',
            $eager_baz_id => '{"class":"Baz","id":"' . $eager_baz_id . '","instance":{"$!hash":["ref",' . $eager_baz_hash_id . ']}}',
            $eager_baz_hash_id => '{"id":' . $eager_baz_hash_id . ',"instance":{"i":3}}',
            $lazy_baz_id => '{"class":"Baz","id":"' . $lazy_baz_id . '","instance":{"$!hash":["ref",' . $lazy_baz_hash_id . ']}}',
            $lazy_baz_hash_id => '{"id":' . $lazy_baz_hash_id . ',"instance":{"i":4}}',
        }
    );
}

done_testing;
