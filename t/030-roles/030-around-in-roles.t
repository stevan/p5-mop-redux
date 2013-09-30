#!perl

use strict;
use warnings;
use 5.016;

use Test::More;

use mop;

sub modifier {
    if ($_[0]->isa('mop::method')) {
        my $method = shift;
        my $type   = shift;
        my $meta   = $method->associated_meta;
        if ($meta->isa('mop::role')) {
            if ( $type eq 'around' ) {
                $meta->bind('after:COMPOSE' => sub {
                    my ($self, $other) = @_;
                    return $other->bind('after:COMPOSE' => __SUB__)
                        unless $other->isa('mop::class');
                    if ($other->has_method( $method->name )) {
                        my $old_method = $other->get_method( $method->name );
                        $other->add_method(
                            $other->method_class->new(
                                name => $method->name,
                                body => sub {
                                    local ${^NEXT} = $old_method->body;
                                    my $self = shift;
                                    $method->execute( $self, [ @_ ] );
                                }
                            )
                        );
                    }
                });
            } elsif ( $type eq 'before' ) {
                die "before not yet supported";
            } elsif ( $type eq 'after' ) {
                die "after not yet supported";
            } else {
                die "I have no idea what to do with $type";
            }
        } elsif ($meta->isa('mop::class')) {
            die "modifiers on classes not yet supported";
        }
    }
}

role Foo {
    method bar ($x) is modifier('around') {
        "Foo::bar " . ${^NEXT}->($x) . " $x"
    }
}

class Bar with Foo {
    method bar ($x) {
        "Bar::bar"
    }
}

my $bar = Bar->new;
isa_ok($bar, 'Bar');
ok($bar->does('Foo'), '... this does the Foo role');

is($bar->bar(10), 'Foo::bar Bar::bar 10', '... got the value we expected');


done_testing;
