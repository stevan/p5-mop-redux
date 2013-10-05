#!perl

use strict;
use warnings;

use Test::More;

use mop;

role Eq {
    method equal_to;

    method not_equal_to ($other) {
        not $self->equal_to($other);
    }
}

role Comparable with Eq {
    method compare;
    method equal_to ($other) {
        $self->compare($other) == 0;
    }

    method greater_than ($other)  {
        $self->compare($other) == 1;
    }

    method less_than  ($other) {
        $self->compare($other) == -1;
    }

    method greater_than_or_equal_to ($other)  {
        $self->greater_than($other) || $self->equal_to($other);
    }

    method less_than_or_equal_to ($other)  {
        $self->less_than($other) || $self->equal_to($other);
    }
}

role Printable {
    method to_string;
}

class US::Currency with Comparable, Printable {
    has $!amount is ro = 0;

    method compare ($other) {
        $!amount <=> $other->amount;
    }

    method to_string {
        sprintf '$%0.2f USD' => $!amount;
    }
}

ok(mop::meta('Comparable')->does_role( 'Eq' ), '... Comparable does the Eq role');

ok(mop::meta('US::Currency')->does_role( 'Eq' ), '... US::Currency does Eq');
ok(mop::meta('US::Currency')->does_role( 'Comparable' ), '... US::Currency does Comparable');
ok(mop::meta('US::Currency')->does_role( 'Printable' ), '... US::Currency does Printable');

ok(mop::meta('Eq')->requires_method('equal_to'), '... EQ::equal_to is a stub method');
ok(!mop::meta('Eq')->requires_method('not_equal_to'), '... EQ::not_equal_to is NOT a stub method');

my $dollar = US::Currency->new( amount => 10 );
ok($dollar->isa( 'US::Currency' ), '... the dollar is a US::Currency instance');
ok($dollar->does( 'Eq' ), '... the dollar does the Eq role');
ok($dollar->does( 'Comparable' ), '... the dollar does the Comparable role');
ok($dollar->does( 'Printable' ), '... the dollar does the Printable role');

can_ok($dollar, 'equal_to');
can_ok($dollar, 'not_equal_to');

can_ok($dollar, 'greater_than');
can_ok($dollar, 'greater_than_or_equal_to');
can_ok($dollar, 'less_than');
can_ok($dollar, 'less_than_or_equal_to');

can_ok($dollar, 'compare');
can_ok($dollar, 'to_string');

is($dollar->to_string, '$10.00 USD', '... got the right to_string value');

ok($dollar->equal_to( $dollar ), '... we are equal to ourselves');
ok(!$dollar->not_equal_to( $dollar ), '... we are not not equal to ourselves');

ok(US::Currency->new( amount => 20 )->greater_than( $dollar ), '... 20 is greater than 10');
ok(!US::Currency->new( amount => 2 )->greater_than( $dollar ), '... 2 is not greater than 10');

ok(!US::Currency->new( amount => 10 )->greater_than( $dollar ), '... 10 is not greater than 10');
ok(US::Currency->new( amount => 10 )->greater_than_or_equal_to( $dollar ), '... 10 is greater than or equal to 10');

done_testing;
