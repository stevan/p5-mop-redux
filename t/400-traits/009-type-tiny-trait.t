#!perl

use strict;
use warnings;

use Test::More;

BEGIN {
    eval { require Type::Tiny; 1 }
        or ($ENV{RELEASE_TESTING}
            ? die
            : plan skip_all => "This test requires Type::Tiny");
}

use mop;

role TypedMethod {
    has $!arg_types is lazy, rw = $_->_build_arg_types;

    method execute ($invocant, $args) {
        for my $i (0..$#$args) {
            $!arg_types->[$i]->assert_valid($args->[$i])
                if $!arg_types->[$i];
        }
        $self->next::method($invocant, $args);
    }

    method _build_arg_types {
        my $class = $self->associated_meta;

        my ($next, $method);
        do {
            return [] unless $class->superclass;
            $next = mop::meta($class->superclass);
        } while ($next && !($method = $next->get_method($self->name)));

        return [] unless $method->does(__ROLE__);

        return $method->arg_types;
    }
}

sub type {
    if ($_[0]->isa('mop::attribute')) {
        my ($attr, $type) = @_;
        $attr->bind('before:STORE_DATA' => sub { $type->assert_valid( ${ $_[2] } ) });
    }
    elsif ($_[0]->isa('mop::method')) {
        my ($meth, @types) = @_;
        mop::apply_metarole($meth, 'TypedMethod');
        $meth->arg_types(\@types);
    }
}

use Types::Standard -types;

class AbstractClass {
    has $!bar is rw, type(Int);

    method set_bar ($val) {
        $!bar = $val;
    }

    method add_numbers ($a, $b) is type(Int, Int) {
        $a + $b
    }
}

class Foo extends AbstractClass {
    method add_numbers ($a, $b) {
        $a + $b
    }
};

my $foo = Foo->new;
isa_ok($foo, 'Foo');
can_ok($foo, 'bar');

is($foo->bar, undef, '... the value is undef');

eval { $foo->bar(10) };
is($@, "", '... this succeeded');
is($foo->bar, 10, '... the value was set to 10');

eval { $foo->bar([]) };
like(
    $@,
    qr/did not pass type constraint/,
    '... this failed correctly'
);
is($foo->bar, 10, '... the value is still 10');

eval { $foo->set_bar(100) };
is($@, "", '... this succeeded');
is($foo->bar, 100, '... the value was set to 100');

eval { $foo->set_bar([]) };
like(
    $@,
    qr/did not pass type constraint/,
    '... this failed correctly'
);
is($foo->bar, 100, '... the value is still 100');

{
    my $result = eval { $foo->add_numbers(100, 100) };
    is($@, "", '... this succeeded');
    is($result, 200, '... got the result we expected too');
}

eval { $foo->add_numbers([], 20) };
like(
    $@,
    qr/did not pass type constraint/,
    '... this failed correctly'
);

{
    my @traits = mop::traits::util::applied_traits(
        mop::meta('AbstractClass')->get_attribute('$!bar')
    );

    is($traits[0]->{'trait'}, \&rw, '... the read-write trait was applied');
    is($traits[1]->{'trait'}, \&type, '... the type trait was applied');
    is_deeply($traits[1]->{'args'}, ['Int'], '... the type trait was applied with the Int arg');
}

done_testing;


