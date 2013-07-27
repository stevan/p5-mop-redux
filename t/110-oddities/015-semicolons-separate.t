use strict;
use warnings;
use Test::More;

use mop;

class Foo { has $bar }

my $obj  = 'Foo'->new(bar => 42);
my $attr = 'Foo'->mop::get_meta->get_attribute('$bar');

is($attr->fetch_data_in_slot_for($obj), 42);

done_testing;
