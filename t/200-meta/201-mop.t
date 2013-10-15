#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my $Foo = mop::class->new(
    name       => 'Foo',
    superclass => 'mop::object',
);
$Foo->add_attribute($Foo->attribute_class->new(
    name    => '$!foo',
    default => \sub { 'FOO' },
));
rw($Foo->get_attribute('$!foo'));
$Foo->FINALIZE;

{
    my $foo = Foo->new;
    is($foo->foo, 'FOO');
    $foo->foo('BAR');
    is($foo->foo, 'BAR');
}

{
    my $foo = Foo->new(foo => 'BAZ');
    is($foo->foo, 'BAZ');
}

done_testing;
