#!perl

use strict;
use warnings;

use Test::More;

use mop;

is(undef, ${^META},  '... no value for ${^META} in main script');
is(undef, ${^CALLER},  '... no value for ${^CALLER} in main script');

class Foo {

	is(mop::meta('Foo'), ${^META}, '... got the metaclass as expected (in the class body)');
	is(undef, ${^CALLER},  '... no value for ${^CALLER} in class body');

	method bar {
		is($self, ${^CALLER}->[0],  '... got the right values in ${^CALLER}');
		is('bar', ${^CALLER}->[1],  '... got the right values in ${^CALLER}');
		is(mop::meta('Foo'), ${^CALLER}->[2],  '... got the right values in ${^CALLER}');
	}
}

is(undef, ${^META},  '... no value for ${^META} in main script (after class creation)');
is(undef, ${^CALLER},  '... no value for ${^CALLER} in main script (after class creation)');

my $Foo = mop::meta('Foo');

$Foo->add_method(
	$Foo->method_class->new(
		name => 'baz',
		body => sub {
			my $self = shift;
			is(undef, ${^CALLER}, '... no value for ${^CALLER} in method installed via add_method');
		}
	)
);

$Foo->FINALIZE;

my $foo = Foo->new;
isa_ok($foo, 'Foo');
can_ok($foo, 'bar');
can_ok($foo, 'baz');

$foo->bar;
$foo->baz;

is(undef, ${^META},  '... no value for ${^META} in main script (after method execution)');
is(undef, ${^CALLER},  '... no value for ${^CALLER} in main script (after method execution)');

done_testing;