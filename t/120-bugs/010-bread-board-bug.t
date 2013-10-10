#!perl

use strict;
use warnings;

use Test::More;

use mop;

=pod

This issue came up after doy made a number of
tweaks to the role composition and it uncovered
an issue with the mop::internals::observable role,
which basically boiled down to the fact it wasn't
properly storing SCALAR refs in the $callbacks
fieldhash. This is just a simple test to
check for this specific issue.

=cut

role Traversable {
    has $!parent is rw, weak_ref;
}

{
    local $@;
    eval q[role Service with Traversable {}];
    is($@, '', '... this worked');
}

done_testing;
