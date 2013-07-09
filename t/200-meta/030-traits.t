#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

sub rw {
    my ($meta, $name) = @_;
    my $attr = $meta->get_attribute($name);
    $meta->add_method( 
        $meta->method_class->new(
            name => $attr->key_name, 
            body => sub {
                my $self = shift;
                $attr->store_data_in_slot_for($self, shift) if @_;
                $attr->fetch_data_in_slot_for($self);
            }
        )
    );
}

class Foo {
    has $bar is rw;
}

my $foo = Foo->new;
isa_ok($foo, 'Foo');
can_ok($foo, 'bar');

is($foo->bar, undef, '... got the value we expected');

is(exception{ $foo->bar(10) }, undef, '... setting the value worked');

is($foo->bar, 10, '... got the value we expected');

done_testing;