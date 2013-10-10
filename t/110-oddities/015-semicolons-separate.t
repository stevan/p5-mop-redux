use strict;
use warnings;
use Test::More;

use mop;

{
    local $@;
    eval q[class Foo { has $!bar }];
    is($@, '', '... no exception was thrown');
}

my $obj  = Foo->new(bar => 42);
my $attr = mop::meta('Foo')->get_attribute('$!bar');

is($attr->fetch_data_in_slot_for($obj), 42);

done_testing;
