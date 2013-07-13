#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

BEGIN {
    eval { require Moose::Util::TypeConstraints; 1 }
        or plan skip_all => "This test requires Moose::Util::TypeConstraints";
}

sub type {
    my $meta = shift;
    my %args = @_;
    if (exists $args{'attribute'}) {
        my ($attr_name, $type_name) = @{$args{'attribute'}};
        my $type = Moose::Util::TypeConstraints::find_type_constraint( $type_name );
        my $attr = $meta->get_attribute( $attr_name );
        $attr->type_checker(sub { $type->assert_valid( @_ ) });
    }
}

class TypedAttribute extends mop::attribute {
    has $type_checker is rw;

    method store_data_in_slot_for ($instance, $data) {
        $type_checker->( $data );
        $self->next::method($instance, $data);
    }
}

class TypedAttributeClass extends mop::class {
    method attribute_class { 'TypedAttribute' }
}

class Foo metaclass TypedAttributeClass {
    has $bar is rw, type('Int');

    method set_bar ($val) {
        $bar = $val;
    }
}

my $foo = Foo->new;
isa_ok($foo, 'Foo');
can_ok($foo, 'bar');

is($foo->bar, undef, '... the value is undef');

is(exception{ $foo->bar(10) }, undef, '... this succeeded');
is($foo->bar, 10, '... the value was set to 10');

like(
    exception{ $foo->bar([]) }, 
    qr/Validation failed for \'Int\' with value \[  \]/, 
    '... this failed correctly'
);
is($foo->bar, 10, '... the value is still 10');

is(exception{ $foo->set_bar(100) }, undef, '... this succeeded');
is($foo->bar, 100, '... the value was set to 100');

like(
    exception{ $foo->set_bar([]) }, 
    qr/Validation failed for \'Int\' with value \[  \]/, 
    '... this failed correctly'
);
is($foo->bar, 100, '... the value is still 100');

done_testing;


