#!perl

use strict;
use warnings;

use Test::More;

use mop;

=pod

https://github.com/stevan/p5-mop-redux/issues/70

=cut

{
    local $TODO = 'need to figure out the best way to handle this';
    eval q[
        class Foo {
            method glurg {
                my $what = "glurg" # missing semicolon
                print "$what\n";
            }
        }
    ];
    like(
        $@,
        qr/^Error while parsing body for method glurg in Foo. Will not continue./,
        '... got the error we expected'
    );
}

done_testing;