#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my $called;

package My::DBIx::Class::Schema {
    BEGIN { $INC{'My/DBIx/Class/Schema.pm'} = __FILE__ }
    sub new { bless {}, shift }
    sub load_namespaces { $called++ }
}

sub incremented {
    my ($meta) = @_;
    for my $method ($meta->methods) {
        next if $method->name eq 'new';
        $method->bind('after:EXECUTE' => sub {
            my ($e, $invocant, $args, $result) = @_;
            $result->[0]++;
        });
    }
}

BEGIN { $called = 0 }
class My::Schema extends My::DBIx::Class::Schema is extending_non_mop, incremented {
    __CLASS__->load_namespaces;
    has $!foo is lazy = 42;
    method foo { $!foo }
}
BEGIN { is($called, 1) }

is(My::Schema->new->foo, 43);

done_testing;
