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
    # At this point the metaclass
    # layer class to role relationship
    # is correct. And the following
    #   - Class does Role 
    #   - Role is instance of Class
    #   - Role does Role
    # is true.
    mop::class->metaclass->add_role( mop::role->metaclass );
    mop::role->metaclass->compose_into( mop::class->metaclass );
    {  
        # NOTE:
        # This is ugly, but we need to do
        # it to set the record straight 
        # and make sure that the relationship
        # between mop::class and mop::role 
        # are correct and code is reused.
        # - SL
        my $classClass = mop::util::get_stash_for('mop::class');
        foreach my $method ( values %{ mop::role->metaclass->methods }) {
            $classClass->add_symbol( '&' . $method->name, $method->body )
                unless $classClass->has_symbol( '&' . $method->name );
        }
        @{ $classClass->get_symbol('@ISA') } = ('mop::object');
    }
    $BOOTSTRAPPED = 1;
}

1;

__END__
