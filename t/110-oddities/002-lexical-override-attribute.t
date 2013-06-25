#!perl

use strict;
use warnings;

use Test::More;
use Test::Warn;

use mop;

=pod

Since attributes are viewed as
lexically scoped variables, it
is possible to overwrite the
name (which is dumb, but you
can do it). And this is fine
as long as the scope doesn't
bleed into other scopes (and
it doesn't).

=cut

warning_like { 
    eval q[
        class Foo {
            has $bar = 99;

            method bar { $bar }

            method test {
                my $bar = 'bottles of beer';
                join " " => ( $self->bar, $bar );
            }
        }
    ] 
}
qr/^\"my\" variable \$bar masks earlier declaration in same scope/,
'... got the warning at compile time';

my $foo = Foo->new;

is( $foo->test, '99 bottles of beer', '... this worked as expected' );

done_testing;



