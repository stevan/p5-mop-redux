package mop;

use v5.16;
use mro;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

our $BOOTSTRAPPED = 0;

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
    $_->metaclass for qw[
        mop::object
        mop::role
        mop::class
        mop::attribute
        mop::method
    ];
    $BOOTSTRAPPED = 1;
}

1;

__END__
