#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my $called;

sub trace {
    my ($class) = @_;
    $class->bind('before:FINALIZE' => sub {
        my $meta = shift;
        for my $method ($meta->methods) {
            $method->bind('before:EXECUTE' => sub {
                $called = 1;
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
