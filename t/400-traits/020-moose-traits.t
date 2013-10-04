#!perl

use strict;
use warnings;

use Test::More;

use mop;

=pod

This was just an experiment to see how much of
Moose's attribute options could be replicated
(at least partially) via traits.

Note, these are very niave implementations,
they are unable to coordinate with one another
so it is possible you can make some messes
with them. But is it just a proof of concept
for now.

=cut

sub predicate {
    my $meta = shift;
    if ($meta->isa('mop::attribute')) {
        my $name  = shift;
        my $class = $meta->associated_meta;
        $class->add_method(
            $class->method_class->new(
                name => $name,
                body => sub { $meta->has_data_in_slot_for( $_[0] ) }
            )
        );
    }
}

sub handles {
    my $meta = shift;
    if ($meta->isa('mop::attribute')) {
        my $handles = shift;
        my $class = $meta->associated_meta;
        foreach my $name ( keys %$handles ) {
            my $other_name = $handles->{$name};
            $class->add_method(
                $class->method_class->new(
                    name => $name,
                    body => sub {
                        my $self = shift;
                        $meta->fetch_data_in_slot_for( $self )->$other_name( @_ );
                    }
                )
            );
        }
    }
}

sub trigger {
    my $meta = shift;
    if ($meta->isa('mop::attribute')) {
        my $trigger = shift;
        $meta->bind('after:STORE_DATA' => sub {
            my (undef, $instance, $data) = @_;
            $trigger->($instance, ${ $data });
        });
    }
}

class Bar {
    method bar { 'BAR' }
    method baz { 'BAZ' }
}

class Foo {

    has $!bar is ro = $_->_build_bar;

    has $!baz is rw, predicate('has_baz');

    has $!gorch is rw, predicate('has_gorch'), lazy = $_->_build_gorch;

    has $!bar_object is handles({ 'test_bar' => 'bar', 'test_baz' => 'baz' }) = do { die '$bar_object is required' };

    has $!bling_was_triggered is rw;

    has $!bling is rw, trigger(sub { $_[0]->bling_was_triggered( $_[1] ) });

    method _build_bar { 100 }

    method _build_gorch {
        $self->bar * 3;
    }
}

my $foo = eval { Foo->new( bar_object => Bar->new ) };
is($@, "", '... created Foo successfully');

isa_ok($foo, 'Foo');

is($foo->bar, 100, '... the revised traitless build process trait worked');

ok(!$foo->has_baz, '... no baz here');
$foo->baz(100);
ok($foo->has_baz, '... we have baz now');

ok(!$foo->has_gorch, '... no gorch yet');
is($foo->gorch, 300, '... got the lazy value');
ok($foo->has_gorch, '... have gorch now');

is($foo->gorch, 300, '... got the lazy value (again)');

can_ok($foo, 'test_bar');
can_ok($foo, 'test_baz');

is($foo->test_bar, 'BAR', '... got the right value');
is($foo->test_baz, 'BAZ', '... got the right value');

ok(!$foo->bling_was_triggered, '... bling has not been triggered yet');

$foo->bling(20);
is($foo->bling_was_triggered, 20, '... bling has now been triggered yet');

eval { Foo->new };
like($@, qr/\$bar_object is required/, '... failed to create Foo (successfully)');



done_testing;
