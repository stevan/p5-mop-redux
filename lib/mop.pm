package mop;

use strict;
use warnings;

BEGIN {
    $::CLASS = shift;
}

use mop::class;
use mop::method;
use mop::attribute;

use mop::internals::syntax;
use mop::internals::mro;

sub import {
    shift;
    mop::internals::syntax->setup_for( caller );
}

1;

__END__
