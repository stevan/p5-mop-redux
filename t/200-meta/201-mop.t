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
    default => sub { 'FOO' },
));
$Foo->add_attribute($Foo->attribute_class->new(
    name    => '$!bar',
    default => 1,
));
eval {
    $Foo->add_attribute($Foo->attribute_class->new(
        name    => '$!baz',
        default => {},
    ));
};
like($@, qr/References of type \(HASH\) are not supported/);
rw($Foo->get_attribute('$!foo'));
ro($Foo->get_attribute('$!bar'));
$Foo->FINALIZE;

{
    my $foo = Foo->new;
    is($foo->foo, 'FOO');
    $foo->foo('BAR');
    is($foo->foo, 'BAR');
    is($foo->bar, 1);
    eval { $foo->bar(2) };
    like($@, qr/Cannot assign to a read-only accessor/);
}

{
    my $foo = Foo->new(foo => 'BAZ');
    is($foo->foo, 'BAZ');
}

done_testing;
