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
        Some->new(x => $num);
    } else {
        None->new;
    }
}

number_under_ten(12)->get_or_else(sub {
    pass("... did not get a number under 10");
});

is(number_under_ten(5)->map(sub { $_[0] * 2 })->get, 10, '... mapped successfully');
is(number_under_ten(5)->flatmap(sub { $_[0] * 2 }), 10, '... flat-mapped successfully');

done_testing;