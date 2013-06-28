#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

class ValidatedAttribute (extends => 'mop::attribute') {
    has $validator = do { sub { 1 } };

    method validator { $validator }
}

class ValidatedAccessorMeta (extends => 'mop::class') {

    method attribute_class { 'ValidatedAttribute' }

    method FINALIZE {

        foreach my $attribute ( values %{ $self->attributes } ) {
            my $name          = $attribute->name;
            my $validator     = $attribute->validator;
            my $accessor_name = $attribute->key_name;

            $self->add_method(
                $self->method_class->new(
                    name => $accessor_name,
                    body => sub {
                        my $self = shift;
                        if (@_) {
                            my $value = shift;
                            die "invalid value '$value' for attribute '$name'"
                                unless $validator->($value);
                            $attribute->store_data_in_slot_for($self, $value);
                        }
                        $attribute->fetch_data_in_slot_for($self);
                    }
                )
            );
        }

        $self->mop::next::method;
    }
}

class Foo (metaclass => 'ValidatedAccessorMeta') {
    has $bar;
    has $baz;
    has $age (validator => sub { $_[0] =~ /^\d+$/ });
}

ok(Foo->metaclass->has_method('bar'), '... the bar method was generated for us');
ok(Foo->metaclass->has_method('baz'), '... the baz method was generated for us');

{
    my $foo = Foo->new;
    ok($foo->isa( 'Foo' ), '... we is-a Foo');
    ok($foo->isa( 'mop::object' ), '... we is-a Object');

    is($foo->bar, undef, '... there is no value for bar');
    is($foo->baz, undef, '... there is no value for baz');
    is($foo->age, undef, '... there is no value for age');

    is(exception { $foo->bar( 100 ) }, undef, '... set the bar value without dying');
    is(exception { $foo->baz( 'BAZ' ) }, undef, '... set the baz value without dying');
    is(exception { $foo->age( 34 ) }, undef, '... set the age value without dying');

    is($foo->bar, 100, '... and got the expected value for bar');
    is($foo->baz, 'BAZ', '... and got the expected value for bar');
    is($foo->age, 34, '... and got the expected value for age');

    like(exception { $foo->age( 'not an int' ) }, qr/invalid value 'not an int' for attribute '\$age'/, '... could not set to a non-int value');

    is($foo->age, 34, '... kept the old value of age');
}

done_testing;

