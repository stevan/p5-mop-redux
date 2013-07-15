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
    if ($_[0]->isa('mop::attribute')) {
        my ($attr, $type_name) = @_;
        my $type = Moose::Util::TypeConstraints::find_type_constraint( $type_name );
        $attr->type_checker(sub { $type->assert_valid( @_ ) });
    }
    elsif ($_[0]->isa('mop::method')) {
        my ($meth, @type_names) = @_;
        my @types = map { Moose::Util::TypeConstraints::find_type_constraint( $_ ) } @type_names;
        $meth->sig_checker(sub {
            my @args = @{ $_[0] };
            foreach my $i ( 0 .. $#args ) {
                $types[ $i ]->assert_valid( $args[ $i ] );
            }
        });
    }
}

class TypedAttribute extends mop::attribute {
    has $type_checker is rw;

    method store_data_in_slot_for ($instance, $data) {
        $type_checker->( $data ) if $type_checker;
        $self->next::method($instance, $data);
    }
}

class TypedMethod extends mop::method {
    has $sig_checker is rw;

    method execute ($invocant, $args) {
        $sig_checker->( $args ) if $sig_checker;
        $self->next::method( $invocant, $args );
    }
}

class TypedClass extends mop::class {
    method attribute_class { 'TypedAttribute' }
    method method_class    { 'TypedMethod'    }
}

class Foo metaclass TypedClass {
    has $bar is rw, type('Int');

    method set_bar ($val) {
        $bar = $val;
    }

    method add_numbers ($a, $b) is type('Int', 'Int') {
        $a + $b
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

{
    my $result;
    is(exception{ $result = $foo->add_numbers(100, 100) }, undef, '... this succeeded');
    is($result, 200, '... got the result we expected too');
}

like(
    exception{ $foo->add_numbers([], 20) },
    qr/Validation failed for \'Int\' with value \[  \]/,
    '... this failed correctly'
);

done_testing;


