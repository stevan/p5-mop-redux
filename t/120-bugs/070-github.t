#!perl

use strict;
use warnings;

use Test::More;

use mop;

=pod

https://github.com/stevan/p5-mop-redux/issues/70

=cut

{
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
        qr/syntax error at.*near.*glurg.*\nExecution.*aborted/s,
        '... got the error we expected'
    );
}

done_testing;