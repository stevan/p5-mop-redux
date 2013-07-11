#!perl

use strict;
use warnings;

use Test::More;

use mop;

sub overload {
    my $meta = shift;
    my (%args) = @_;

    if (exists $args{'method'}) {
        my ($method_name, $operator) = @{$args{'method'}};
        my $method = $meta->get_method($method_name);

        # NOTE:
        # We are actually installing the overloads
        # into the package directly, this works 
        # because the MRO stuff doesn't actually 
        # get used if the the methods are local 
        # to the package. This should avoid some
        # complexity (perhaps). 

        # don't load it unless you 
        # have too, it adds a speed
        # penalty to the runtime
        require overload;
        overload::OVERLOAD(
            $meta->name, 
            $operator,
            sub { $method->execute( shift( @_ ), [ @_ ] ) },

            # XXX:
            # This is stupid that we need to actually
            # override this stuff, fallback => 1 should
            # just work, but for some reason it doesn't
            # so meh.
            # - SL
            '""' => sub { $_[0] }, 
            fallback => 1
        );
    }
}

class Foo {
    has $val;

    method add ($b) is overload('+') {
        $val + $b
    }

    method subtract ($b) is overload('-') {
        $val - $b
    }

    method equals ($b) is overload('==') {
        $val == $b
    }
}

my $foo = Foo->new( val => 10 );

is($foo + 1, 11, '... got the right value');
is($foo - 1, 9,  '... got the right value');

ok($foo == 10, '... got the right value');

pass("... this actually parsed!");

done_testing;