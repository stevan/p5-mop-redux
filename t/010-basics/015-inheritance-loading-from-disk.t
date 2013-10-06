#!perl

use strict;
use warnings;

use Test::More;

use lib 't/lib';

use_ok 'Level3', '... use Level3 works';

is_deeply(
    mro::get_linear_isa('Level3'),
    [ 'Level3', 'Level2', 'Level1', 'Root', 'mop::object' ],
    '... Level3 MRO contains all relevant classes'
);

my $level3 = Level3->new( foo => 10 );
isa_ok($level3, 'Level3');
isa_ok($level3, 'Level2');
isa_ok($level3, 'Level1');
isa_ok($level3, 'Root');

is($level3->foo, 10, '... got the right value from our attribute');

done_testing;

__END__
