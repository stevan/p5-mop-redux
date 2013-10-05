#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

class ValidatedAttribute extends mop::attribute {
    has $!validator is ro = sub { 1 };
}

class ValidatedAccessorMeta extends mop::class {

    method attribute_class { 'ValidatedAttribute' }

    method FINALIZE {

        foreach my $attribute ( $self->attributes ) {
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

        $self->next::method;
    }
}

sub validated {
    my ($meta, $validator) = @_;
    my $meta_attr = mop::meta($meta)->get_attribute('$!validator');
    $meta_attr->store_data_in_slot_for($meta, $validator);
}

class Foo meta ValidatedAccessorMeta {
    has $!bar;
    has $!baz;
    has $!age is validated(sub { $_[0] =~ /^\d+$/ });
}

ok(mop::meta('Foo')->has_method('bar'), '... the bar method was generated for us');
ok(mop::meta('Foo')->has_method('baz'), '... the baz method was generated for us');

{
    my $foo = Foo->new;
    ok($foo->isa( 'Foo' ), '... we is-a Foo');
    ok($foo->isa( 'mop::object' ), '... we is-a Object');

    is($foo->bar, undef, '... there is no value for bar');
    is($foo->baz, undef, '... there is no value for baz');
    is($foo->age, undef, '... there is no value for age');

    eval { $foo->bar( 100 ) };
    is($@, "", '... set the bar value without dying');
    eval { $foo->baz( 'BAZ' ) };
    is($@, "", '... set the baz value without dying');
    eval { $foo->age( 34 ) };
    is($@, "", '... set the age value without dying');

    is($foo->bar, 100, '... and got the expected value for bar');
    is($foo->baz, 'BAZ', '... and got the expected value for bar');
    is($foo->age, 34, '... and got the expected value for age');

    eval { $foo->age( 'not an int' ) };
    like($@, qr/invalid value 'not an int' for attribute '\$\!age'/, '... could not set to a non-int value');

    is($foo->age, 34, '... kept the old value of age');
}

done_testing;

