#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my $Foo = mop::class->new(
    name       => 'Foo',
    superclass => 'mop::object',
);

$Foo->add_method($Foo->method_class->new(
    name => 'foo',
    body => sub { 'FOO' },
));

ok(!Foo->isa('mop::object'));
ok(!Foo->can('foo'));

$Foo->FINALIZE;

for my $foo (Foo->new, $Foo->new_instance) {
    isa_ok($foo, 'mop::object');
    isa_ok($foo, 'Foo');
    is($foo->foo, 'FOO');
    ok(!Foo->can('bar'));
}

$Foo->add_method($Foo->method_class->new(
    name => 'bar',
    body => sub { 'BAR' },
));

ok(!Foo->can('bar'));

$Foo->FINALIZE;

{
    my $foo = Foo->new;
    is($foo->foo, 'FOO');
    is($foo->bar, 'BAR');
}

my $Baz = mop::role->new(
    name => 'Baz',
);
$Baz->add_method($Baz->method_class->new(
    name => 'baz',
    body => sub { 'BAZ' },
));
$Baz->FINALIZE;

my $Bar = mop::class->new(
    name       => 'Bar',
    superclass => 'Foo',
    roles      => ['Baz'],
    methods    => {
        bar => $Foo->method_class->new(
            name => 'bar',
            body => sub { 'BAR2' },
        ),
    },
);
$Bar->FINALIZE;

for my $bar (Bar->new, $Bar->new_instance) {
    isa_ok($bar, 'mop::object');
    isa_ok($bar, 'Foo');
    isa_ok($bar, 'Bar');
    is($bar->foo, 'FOO');
    is($bar->bar, 'BAR2');
    is($bar->baz, 'BAZ');
    ok(!$bar->can('quux'));
}

role Quux {
    method quux { 'QUUX' }
}

$Bar->add_role('Quux');
$Bar->FINALIZE;

{
    my $bar = Bar->new;
    is($bar->foo, 'FOO');
    is($bar->bar, 'BAR2');
    is($bar->baz, 'BAZ');
    is($bar->quux, 'QUUX');
}

done_testing;
