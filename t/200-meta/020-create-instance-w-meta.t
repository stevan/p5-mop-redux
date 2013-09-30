#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Foo {
    has $!bar;
    method bar { $!bar }
}

#use Data::Dumper;
#warn Dumper(mop::dump_object(mop::meta('Foo')));

{
    my $foo = mop::meta('Foo')->new_instance;
    ok($foo->isa('Foo'), '... it is an instance of Foo');
    ok(!$foo->isa('mop::class'), '... it is not an instance of mop::class');

    ok($foo->can('bar'), '... and has the bar method');
    is($foo->bar, undef, '... bar is undef for now');
}

{
    my $foo = mop::meta('Foo')->new_instance( bar => 10 );
    ok($foo->isa('Foo'), '... it is an instance of Foo');
    ok(!$foo->isa('mop::class'), '... it is not an instance of mop::class');

    ok($foo->can('bar'), '... and has the bar method');
    is($foo->bar, 10, '... bar was assigned to properly');
}

done_testing;