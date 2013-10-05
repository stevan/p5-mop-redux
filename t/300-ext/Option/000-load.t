#!perl

use strict;
use warnings;

use Test::More;

use lib 't/ext/Option';

BEGIN {
    use_ok( 'Option' );
}

sub number_under_ten {
    my $num = shift;
    if ($num < 10) {
        Some->new(val => $num);
    } else {
        None->new;
    }
}

is(number_under_ten(7)->get, 7, '... got the right value back');
eval { number_under_ten(12)->get };
like($@, qr/None\-\>get/, '... got the exception');

number_under_ten(12)->get_or_else(sub {
    pass("... did not get a number under 10");
});

is(number_under_ten(3)->get_or_else(sub {
    fail("... this should never happen");
}), 3, '... got a number under 10');

number_under_ten(20)->or_else(sub {
    pass("... did not get a number under 10");
});

isa_ok(number_under_ten(3)->or_else(sub {
    fail("... this should never happen");
}), 'Some');

ok(number_under_ten(3)->is_defined, '... got a number under 10');
ok(!number_under_ten(15)->is_defined, '... did not get a number under 10');

ok(!number_under_ten(3)->is_empty, '... got a number under 10');
ok(number_under_ten(15)->is_empty, '... did not get a number under 10');

is(number_under_ten(5)->map(sub { $_[0] * 2 })->get, 10, '... mapped successfully');
isa_ok(number_under_ten(15)->map(sub { $_[0] * 2 }), 'None');

is(number_under_ten(5)->flatmap(sub { $_[0] * 2 }), 10, '... flat-mapped successfully');
isa_ok(number_under_ten(25)->flatmap(sub { $_[0] * 2 }), 'None');

done_testing;
