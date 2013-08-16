#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my $called;

sub trace {
    my ($class) = @_;
    $class->bind('after:FINALIZE' => sub {
        my $meta = shift;
        for my $method ($meta->methods) {
            my $body = $method->body;
            my $attr = mop::get_meta($method)->get_attribute('$body');
            $attr->store_data_in_slot_for($method, sub {
                $called = 1;
                $body->();
            });
        }
    });
}

role Foo {
    method foo { 'FOO' }
}

class C1 with Foo is trace { }
class C2 with Foo { }

undef $called;
is(C1->foo, 'FOO');
is($called, 1);

undef $called;
is(C2->foo, 'FOO');
is($called, undef);

done_testing;
