package mop;

use strict;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

BEGIN {
    $::CLASS = shift;
}

use mop::object;
use mop::class;
use mop::method;
use mop::attribute;

use mop::internals::syntax;
use mop::internals::mro;

sub import {
    shift;
    mop::internals::syntax->setup_for( caller );
    bootstrap();
}

sub bootstrap {
    $_->meta for qw[
        mop::object
        mop::class
        mop::attribute
        mop::method
    ];
}

1;

__END__
