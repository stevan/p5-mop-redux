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
        $attr->bind('before:STORE_DATA' => sub { $type->assert_valid( $_[2] ) });
    }
    if (exists $args{'method'}) {
        my ($meth_name, @type_names) = @{$args{'method'}};
        my @types = map { Moose::Util::TypeConstraints::find_type_constraint( $_ ) } @type_names;
        my $meth  = $meta->get_method( $meth_name );
        $meth->bind('before:EXECUTE' => sub {
            my @args = @{ $_[2] };
            foreach my $i ( 0 .. $#args ) {
                $types[ $i ]->assert_valid( $args[ $i ] );
            }
        });
    }
}

class Foo {
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


