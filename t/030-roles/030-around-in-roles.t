#!perl

use strict;
use warnings;

use Test::More;

use mop;

sub around {
    if ($_[0]->isa('mop::method')) {
        my $method = shift;
        my $meta   = $method->associated_meta;
        if ($meta->isa('mop::role')) {
            $meta->bind('after:COMPOSE' => sub {
                my ($self, $other) = @_;
                if ($other->has_method( $method->name )) {
                    my $old_method = $other->remove_method( $method->name );
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
        } elsif ($meta->isa('mop::class')) {
            die "not yet supported";
        }
    }
}

role Foo {
    method bar ($x) is around {
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