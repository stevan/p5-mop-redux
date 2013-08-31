#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use Scalar::Util qw[ isweak ];

use mop;

class Foo {
    has $!bar is rw;

    #submethod DEMOLISH { warn "reapin... " }
}

class Bar {
    has $!foo is rw, weak_ref;
}

my $foo = Foo->new;
my $bar = Bar->new;

$bar->foo($foo);
$foo->bar($bar);

my $store = mop::get_meta('Bar')->get_attribute('$!foo')->storage;

#warn "STORAGE:  " . $store;
#warn "INSTANCE: " . $bar;
#warn "VALUE:    " . $store->{ $bar };

my $x = $store->{ $bar };
ok(isweak($$x), '... this is weak');

#warn $foo->bar;

is($foo->bar, $bar, '... these match');
is($bar->foo, $foo, '... these match');

undef $foo;

is($bar->foo, undef, '... weak ref reaped');


done_testing;
