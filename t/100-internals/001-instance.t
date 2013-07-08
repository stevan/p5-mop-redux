#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use Data::Dumper qw[ Dumper ];

=pod

This was just a proof of concept for how 
we are going about handling attributes.

=cut

{
    package Foo;
    use strict;
    use warnings;

    use Variable::Magic       qw[ wizard cast ];
    use Hash::Util::FieldHash qw[ fieldhash ];

    fieldhash my %foo;

    my $wiz = wizard(
        data => sub { $_[1] },
        get  => sub { ${ $_[0] } = ${ $_[1]->[0]->{ $_[1]->[1] } || \undef }; },
        set  => sub { $_[1]->[0]->{ $_[1]->[1] } = $_[0] },
    );

    sub new { bless \(my $y) => shift }

    sub foo {
        my $self = shift;
        my $foo;
        cast $foo, $wiz, [ \%foo, $self ]; 

        $foo = shift if @_;
        $foo;
    }

}

my $foo = Foo->new;

is($foo->foo, undef, '... got nothing yet');

is($foo->foo(10), 10, '... got the value we expected');
is($foo->foo, 10, '... got the value we expected');

my $x = $foo->foo([ 2, 3, 4 ]);

is_deeply($x, [ 2, 3, 4 ], '... got the value we expected');
is_deeply($foo->foo, [ 2, 3, 4 ], '... got the value we expected');

# check to make sure altering 
# the value outside of the object
# still works as expected.
push @$x => 10;

is_deeply($x, [ 2, 3, 4, 10 ], '... got the value we expected');
is_deeply($foo->foo, [ 2, 3, 4, 10 ], '... got the value we expected');

done_testing;