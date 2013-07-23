#!perl

use strict;
use warnings;

use Test::More;

use mop;

is(undef, ${^SELF},  '... no value for ${^SELF} in main script');
is(undef, ${^CLASS}, '... no value for ${^CLASS} in main script');
is(undef, ${^ROLE},  '... no value for ${^ROLE} in main script');
is(undef, ${^META},  '... no value for ${^META} in main script');
is(undef, ${^CALLER},  '... no value for ${^CALLER} in main script');

role Foo {

	is(mop::get_meta('Foo'), ${^META}, '... got the metaclass as expected (in the role body)');
	is(mop::get_meta('Foo'), ${^ROLE}, '... got the metaclass as expected (in the role body)');
	is(undef, ${^CLASS}, '... no value for ${^CLASS} in role body');
	is(undef, ${^CALLER},  '... no value for ${^CALLER} in role body');

	method bar {
		is($class, 'Bar', '... got the value for $class we expected');
		is($self, ${^SELF}, '... got the invocant as expected');
		is(mop::get_meta('Bar'), ${^CLASS}, '... got the metaclass as expected (in the method)');
		is(undef, ${^ROLE}, '... no value for ${^ROLE} in method');
		is($self, ${^CALLER}->[0],  '... got the right values in ${^CALLER}');
		is('bar', ${^CALLER}->[1],  '... got the right values in ${^CALLER}');
		is(mop::get_meta('Foo'), ${^CALLER}->[2],  '... got the right values in ${^CALLER}');
	}
}

is(undef, ${^SELF},  '... no value for ${^SELF} in main script (after role creation)');
is(undef, ${^CLASS}, '... no value for ${^CLASS} in main script (after role creation)');
is(undef, ${^ROLE},  '... no value for ${^ROLE} in main script (after role creation)');
is(undef, ${^META},  '... no value for ${^META} in main script (after role creation)');
is(undef, ${^CALLER},  '... no value for ${^CALLER} in main script (after role creation)');

my $Foo = mop::get_meta('Foo');

$Foo->add_method(
	$Foo->method_class->new(
		name => 'baz',
		body => sub {
			my $self = shift;
			is($self, ${^SELF}, '... got the invocant as expected');
			is(mop::get_meta('Bar'), ${^CLASS}, '... got the metaclass as expected (in the method)');
			is(undef, ${^ROLE}, '... no value for ${^ROLE} in method');
			is(undef, ${^CALLER}, '... no value for ${^CALLER} in method installed via add_method');
		}
	)
);

eval "class Bar with Foo {}";
die $@ if $@;

my $bar = Bar->new;
isa_ok($bar, 'Bar');
ok($bar->does('Foo'), '... bar does the Foo role');
can_ok($bar, 'bar');
can_ok($bar, 'baz');

$bar->bar;
$bar->baz;

is(undef, ${^SELF},  '... no value for ${^SELF} in main script (after method execution)');
is(undef, ${^CLASS}, '... no value for ${^CLASS} in main script (after method execution)');
is(undef, ${^ROLE},  '... no value for ${^ROLE} in main script (after method execution)');
is(undef, ${^META},  '... no value for ${^META} in main script (after method execution)');
is(undef, ${^CALLER},  '... no value for ${^CALLER} in main script (after method execution)');

done_testing;