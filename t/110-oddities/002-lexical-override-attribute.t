#!perl

use strict;
use warnings;

use Test::More;

use mop;

=pod

NOTE:
This test is actually no longer
needed now that we have twigils
- SL

This behavior is now different then
it used to be (and then it was in
the old prototype), see the
t/100-internals/001-instance.t test
for a de-compiled example of what
is being done under the covers.

=cut

{
    my $warning;
    local $SIG{__WARN__} = sub { $warning .= $_[0] };
    eval q[
        class Foo {
            has $!bar = 99;

            method bar { $!bar }

            method test {
                my $bar = 'bottles of beer';
                join " " => ( $self->bar, $bar );
            }
        }
    ];
    is($warning, undef, '... got no warning at compile time');
}

my $foo = Foo->new;

is( $foo->test, '99 bottles of beer', '... this worked as expected' );

done_testing;



