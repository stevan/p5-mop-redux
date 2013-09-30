#!perl

use strict;
use warnings;

use Test::More;

use mop;

=pod

This test is just a proof of concept, we
can explore this more later.

=cut

sub subclasseable_by_non_mop {
    if ($_[0]->isa('mop::class')) {
        my $meta  = shift;
        my $stash = mop::internals::util::get_stash_for( $meta->name );

        foreach my $method ($meta->methods) {
            $stash->add_symbol('&' . $method->name, $method->body);
        }
    }
}

class Foo is subclasseable_by_non_mop {
    method bar {
        "Foo::bar"
    }
}

{
    package Baz;
    use strict;
    use warnings;

    our @ISA = ('Foo');

    sub new { bless {} => shift }

    sub gorch { "Baz::gorch => " . (shift)->bar }
}

my $baz = Baz->new;
isa_ok($baz, 'Baz');
isa_ok($baz, 'Foo');

is($baz->gorch, 'Baz::gorch => Foo::bar', '... got the value we expected');

done_testing;