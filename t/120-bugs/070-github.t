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
        package Foo {
            sub glurg {
                my $what = "glurg" # missing semicolon
                print "$what\n";
            }
        }
    ];
    my $normal_err = $@ =~ s/\(eval.*line \d+/<LOCATION>/r;
    eval q[
        class Foo {
            method glurg {
                my $what = "glurg" # missing semicolon
                print "$what\n";
            }
        }
    ];
    my $mop_err = $@ =~ s/\(eval.*line \d+/<LOCATION>/r;
    like(
        $mop_err,
        qr/\Q$normal_err/s,
        '... got the error we expected'
    );
}

done_testing;