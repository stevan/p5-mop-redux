#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Thing1 {
	has $!name;
	method name is overload(q[""]) {
		return $!name;
	}
}

class Thing2 extends Thing1 {
	method name {
		return uc($self->next::method);
	}
}

my $thing1 = Thing1->new(name => 'foo');
is("$thing1", 'foo', '... this stringifies correctly');

my $thing2 = Thing2->new(name => 'bar');
is("$thing2", 'BAR', '... this should stringify as well');

done_testing;
