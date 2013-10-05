#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Foo {
    has $!bar is rw;
}

my $foo = Foo->new;
isa_ok($foo, 'Foo');
can_ok($foo, 'bar');

is($foo->bar, undef, '... got the value we expected');

eval { $foo->bar(10) };
is($@, "", '... setting the value worked');

is($foo->bar, 10, '... got the value we expected');

{
    my @traits = mop::traits::util::applied_traits(
        mop::meta('Foo')->get_attribute('$!bar')
    );

    is($traits[0]->{'trait'}, \&rw, '... the read-write trait was applied');
}

class Bar {
    has $!baz is ro;
}

my $bar = Bar->new( baz => 10 );
isa_ok($bar, 'Bar');
can_ok($bar, 'baz');

is($bar->baz, 10, '... got the value we expected');

eval { $bar->baz(10) };
like(
        $@,
	qr/Cannot assign to a read-only accessor/,
	'... setting the value worked'
);

{
    my @traits = mop::traits::util::applied_traits(
        mop::meta('Bar')->get_attribute('$!baz')
    );

    is($traits[0]->{'trait'}, \&ro, '... the read-only trait was applied');
}

class Baz is abstract {}

ok(mop::meta('Baz')->is_abstract, '... class is abstract');

{
    my @traits = mop::traits::util::applied_traits(
        mop::meta('Baz')
    );

    is($traits[0]->{'trait'}, \&abstract, '... the abstract trait was applied');
}

done_testing;
