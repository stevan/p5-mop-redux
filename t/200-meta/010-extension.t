#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

class ClassAccessorMeta extends mop::class {
    method FINALIZE {

        foreach my $attribute ( $self->attributes ) {
            $self->add_method(
                mop::method->new(
                    name => $attribute->key_name,
                    body => sub {
                        my $self = shift;
                        $attribute->store_data_in_slot_for($self, shift ) if @_;
                        $attribute->fetch_data_in_slot_for($self);
                    }
                )
            );
        }

        $self->next::method;
    }
}

class Foo meta ClassAccessorMeta {
    has $!bar;
    has $!baz;
}

ok(mop::meta('Foo')->has_method('bar'), '... the bar method was generated for us');
ok(mop::meta('Foo')->has_method('baz'), '... the baz method was generated for us');

{
    my $foo = Foo->new;
    ok($foo->isa( 'Foo' ), '... we is-a Foo');
    ok($foo->isa( 'mop::object' ), '... we is-a Object');

    is($foo->bar, undef, '... there is no value for bar');
    is($foo->baz, undef, '... there is no value for baz');

    eval { $foo->bar( 100 ) };
    is($@, "", '... set the bar value without dying');
    eval { $foo->baz( 'BAZ' ) };
    is($@, "", '... set the baz value without dying');

    is($foo->bar, 100, '... and got the expected value for bar');
    is($foo->baz, 'BAZ', '... and got the expected value for bar');
}

{
    my $foo = Foo->new( bar => 100, baz => 'BAZ' );
    ok($foo->isa( 'Foo' ), '... we is-a Foo');
    ok($foo->isa( 'mop::object' ), '... we is-a Object');

    is($foo->bar, 100, '... and got the expected value for bar');
    is($foo->baz, 'BAZ', '... and got the expected value for bar');

    eval { $foo->bar( 300 ) };
    is($@, "", '... set the bar value without dying');
    eval { $foo->baz( 'baz' ) };
    is($@, "", '... set the baz value without dying');

    is($foo->bar, 300, '... and got the expected value for bar');
    is($foo->baz, 'baz', '... and got the expected value for bar');
}



done_testing;
