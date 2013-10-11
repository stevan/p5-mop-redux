#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

role Foo {
    has $!foo is ro = 10;
}

class Bar with Foo {
    has $!bar is ro = 20;
}

class Baz extends Bar {
    has $!baz is ro = 30;
}

{
    my $baz = Baz->new;
    is_deeply(
        mop::dump_object($baz),
        {
            __ID__    => mop::id($baz),
            __CLASS__ => 'Baz',
            __SELF__  => $baz,
            '$!foo'   => 10,
            '$!bar'   => 20,
            '$!baz'   => 30,
        }
    );
}

{
    my $bar = Bar->new;
    my $baz = Baz->new(foo => $bar);
    is_deeply(
        mop::dump_object($baz),
        {
            __ID__    => mop::id($baz),
            __CLASS__ => 'Baz',
            __SELF__  => $baz,
            '$!foo'   => {
                __ID__    => mop::id($bar),
                __CLASS__ => 'Bar',
                __SELF__  => $bar,
                '$!foo'   => 10,
                '$!bar'   => 20,
            },
            '$!bar'   => 20,
            '$!baz'   => 30,
        }
    );
}

# see https://github.com/pjcj/Devel--Cover/issues/72
SKIP: { skip "__SUB__ is broken with Devel::Cover", 1 if $INC{'Devel/Cover.pm'};
{
    my $bar = Bar->new(foo => [1, "foo"], bar => { quux => 10 });
    my $baz = Baz->new(baz => { a => [ 2, $bar ] });
    is_deeply(
        mop::dump_object($baz),
        {
            __ID__    => mop::id($baz),
            __CLASS__ => 'Baz',
            __SELF__  => $baz,
            '$!foo'   => 10,
            '$!bar'   => 20,
            '$!baz'   => {
                a => [
                    2,
                    {
                        __ID__    => mop::id($bar),
                        __CLASS__ => 'Bar',
                        __SELF__  => $bar,
                        '$!foo'   => [ 1, "foo" ],
                        '$!bar'   => { quux => 10 },
                    },
                ],
            },
        }
    );
}
}

class Quux {
    has $!storage = 10;
}

{
    my $quux = Quux->new;
    is_deeply(
        mop::dump_object($quux),
        {
            __ID__      => mop::id($quux),
            __CLASS__   => 'Quux',
            __SELF__    => $quux,
            '$!storage' => 10,
        }
    );
}

# see https://github.com/pjcj/Devel--Cover/issues/72
SKIP: { skip "__SUB__ is broken with Devel::Cover", 4 if $INC{'Devel/Cover.pm'};
{
    my $Foo = mop::meta('Foo');
    my $dump = mop::dump_object($Foo);

    is(
        $dump->{'$!attributes'}{'$!foo'}{'__SELF__'},
        $Foo->get_attribute('$!foo'),
    );
    delete $dump->{'$!attributes'}{'$!foo'};
    is(
        $dump->{'$!methods'}{'foo'}{'__SELF__'},
        $Foo->get_method('foo'),
    );
    delete $dump->{'$!methods'}{'foo'};

    is_deeply(
        $dump,
        {
            __ID__               => mop::id($Foo),
            __CLASS__            => 'mop::role',
            __SELF__             => $Foo,
            '$!name'             => 'Foo',
            '$!version'          => undef,
            '$!authority'        => undef,
            '$!roles'            => [],
            '$!attributes'       => {},
            '$!methods'          => {},
            '$!required_methods' => {},
            '$!callbacks'        => undef,
        }
    );
}

{
    my $Bar = mop::meta('Bar');
    my $dump = mop::dump_object($Bar);

    is(
        $dump->{'$!attributes'}{'$!foo'}{'__SELF__'},
        $Bar->get_attribute('$!foo'),
    );
    delete $dump->{'$!attributes'}{'$!foo'};
    is(
        $dump->{'$!methods'}{'foo'}{'__SELF__'},
        $Bar->get_method('foo'),
    );
    delete $dump->{'$!methods'}{'foo'};
    is(
        $dump->{'$!attributes'}{'$!bar'}{'__SELF__'},
        $Bar->get_attribute('$!bar'),
    );
    delete $dump->{'$!attributes'}{'$!bar'};
    is(
        $dump->{'$!methods'}{'bar'}{'__SELF__'},
        $Bar->get_method('bar'),
    );
    delete $dump->{'$!methods'}{'bar'};
    is(
        $dump->{'$!roles'}[0]{'__SELF__'},
        mop::meta('Foo'),
    );
    shift @{ $dump->{'$!roles'} };
    is(ref($dump->{'$!instance_generator'}), 'CODE');
    delete $dump->{'$!instance_generator'};

    is_deeply(
        $dump,
        {
            __ID__               => mop::id($Bar),
            __CLASS__            => 'mop::class',
            __SELF__             => $Bar,
            '$!name'             => 'Bar',
            '$!version'          => undef,
            '$!authority'        => undef,
            '$!roles'            => [],
            '$!attributes'       => {},
            '$!methods'          => {},
            '$!required_methods' => {},
            '$!callbacks'        => undef,
            '$!superclass'       => 'mop::object',
            '$!is_abstract'      => 0,
        }
    );
}

{
    my $Bar = mop::meta('Bar');
    my $bar = $Bar->get_attribute('$!bar');
    my $dump = mop::dump_object($bar);

    is(ref($dump->{'$!default'}), 'REF');
    is(ref(${ $dump->{'$!default'} }), 'CODE');
    delete $dump->{'$!default'};
    is($dump->{'$!associated_meta'}{'__SELF__'}, $Bar);
    delete $dump->{'$!associated_meta'};

    is_deeply(
        $dump,
        {
            __ID__          => mop::id($bar),
            __CLASS__       => 'mop::attribute',
            __SELF__        => $bar,
            '$!name'        => '$!bar',
            '$!storage'     => '__INTERNAL_DETAILS__',
            '$!original_id' => mop::id($bar),
            '$!callbacks'   => undef,
        }
    );
}

{
    my $Bar = mop::meta('Bar');
    my $bar = $Bar->get_method('bar');
    my $dump = mop::dump_object($bar);

    is(ref($dump->{'$!body'}), 'CODE');
    delete $dump->{'$!body'};
    is($dump->{'$!associated_meta'}{'__SELF__'}, $Bar);
    delete $dump->{'$!associated_meta'};

    is_deeply(
        $dump,
        {
            __ID__          => mop::id($bar),
            __CLASS__       => 'mop::method',
            __SELF__        => $bar,
            '$!name'        => 'bar',
            '$!original_id' => mop::id($bar),
            '$!callbacks'   => undef,
        }
    );
}
}

{
    my $nonmop = bless {}, 'NonMop';
    my $bar = Bar->new(bar => $nonmop);
    is_deeply(
        mop::dump_object($bar),
        {
            __ID__          => mop::id($bar),
            __CLASS__       => 'Bar',
            __SELF__        => $bar,
            '$!foo'         => 10,
            '$!bar'         => $nonmop,
        }
    );
}

done_testing;
