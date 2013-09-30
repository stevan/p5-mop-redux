package mop;

use v5.16;
use mro;
use warnings;

use Sub::Install;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

our $BOOTSTRAPPED = 0;

use mop::object;
use mop::class;
use mop::method;
use mop::attribute;

use mop::observable;

use mop::internals::syntax;
use mop::internals::mro;

use mop::traits;
use mop::traits::util;
use mop::util;

sub import {
    shift;
    my $pkg = caller;
    mop::internals::syntax->setup_for( $pkg );
    bootstrap();

    foreach my $trait ( @mop::traits::AVAILABLE_TRAITS ) {
        Sub::Install::install_sub({
            code => $trait,
            into => $pkg,
            from => 'mop::traits'
        });
    }
}

sub unimport {
    my $pkg = caller;
    mop::util::get_stash_for($pkg)->remove_glob($_)
        for (
            qw(class role method submethod has),
            @mop::traits::AVAILABLE_TRAITS
        );
}

sub get_meta {
    my $class = shift;
    die "Could not find metaclass for $class"
      unless mop::util::has_meta( $class );
    mop::util::find_meta( $class );
}

sub bootstrap {
    return if $BOOTSTRAPPED;
    $_->__INIT_METACLASS__ for qw[
        mop::object
        mop::role
        mop::class
        mop::attribute
        mop::method
        mop::observable
    ];

    my $Object = mop::util::find_meta('mop::object');

    my $Role  = mop::util::find_meta('mop::role');
    my $Class = mop::util::find_meta('mop::class');

    my $Method     = mop::util::find_meta('mop::method');
    my $Attribute  = mop::util::find_meta('mop::attribute');
    my $Observable = mop::util::find_meta('mop::observable');

    # At this point the metaclass
    # layer class to role relationship
    # is correct. And the following
    #   - Class does Role
    #   - Role is instance of Class
    #   - Role does Role
    # is true.
    $Class->consume_role( $Role );

    # make attribute and method into
    # observables
    foreach my $meta ( $Method, $Attribute, $Class, $Role ) {
        $meta->consume_role($Observable);
    }

    {
        my $Object_stash    = mop::util::get_stash_for('mop::object');
        my $Class_stash     = mop::util::get_stash_for('mop::class');
        my $Role_stash      = mop::util::get_stash_for('mop::role');
        my $Method_stash    = mop::util::get_stash_for('mop::method');
        my $Attribute_stash = mop::util::get_stash_for('mop::attribute');

        # NOTE:
        # This is ugly, but we need to do
        # it to set the record straight
        # and make sure that the relationship
        # between mop::class and mop::role
        # are correct and code is reused.
        # - SL
        foreach my $method ($Role->methods) {
            $Class_stash->add_symbol( '&' . $method->name, $method->body )
                unless $Class_stash->has_symbol( '&' . $method->name );
        }

        # now make sure the Observable roles are
        # completely intergrated into the stashes
        foreach my $method ($Observable->methods) {
            foreach my $stash ( $Role_stash, $Method_stash, $Attribute_stash ) {
                $stash->add_symbol( '&' . $method->name, $method->body )
                    unless $stash->has_symbol( '&' . $method->name );
            }
        }

        # then clean up some of the @ISA by
        # removing mop::observable from them
        @{ $Role_stash->get_symbol('@ISA')      } = ('mop::object');
        @{ $Method_stash->get_symbol('@ISA')    } = ('mop::object');
        @{ $Attribute_stash->get_symbol('@ISA') } = ('mop::object');

        # Here we finalize the rest of the
        # metaclass layer so that the following:
        #   - Class is an instance of Class
        #   - Object is an instance of Class
        #   - Class is a subclass of Object
        # is true.
        @{ $Class_stash->get_symbol('@ISA') } = ('mop::object');

        # remove the temporary clone methods used in the bootstrap
        $Method_stash->remove_symbol('&clone');

        # replace the temporary implementation of mop::object::new
        my $new = mop::method->new(
            name => 'new',
            body => sub {
                my $class = shift;
                my %args  = scalar(@_) == 1 && ref $_[0] eq 'HASH'
                    ? %{$_[0]}
                    : @_;
                mop::util::find_or_create_meta($class)->new_instance(%args);
            },
        );
        $Object->add_method($new);
        $Object_stash->add_symbol('&new', $new->body);
    }

    {
        my $old_next_method = \&next::method;
        my $old_next_can    = \&next::can;
        no warnings 'redefine';
        *next::method = sub {
            my $invocant = shift;
            if ( mop::util::has_meta( $invocant ) ) {
                $invocant->mop::next::method( @_ )
            } else {
                $invocant->$old_next_method( @_ )
            }
        };

        *next::can = sub {
            my $invocant = shift;
            if ( mop::util::has_meta( $invocant ) ) {
                $invocant->mop::next::can( @_ )
            } else {
                $invocant->$old_next_can( @_ )
            }
        };

    }

    $BOOTSTRAPPED = 1;
}

1;

__END__

=pod

=head1 NAME

mop - A meta-object protocol for Perl 5

=head1 VERSION

version 0.01

=head1 SYNOPSIS

    class Point {
        has $x is ro = 0;
        has $y is ro = 0;

        method clear {
            ($x, $y) = (0, 0);
        }
    }

    class Point3D extends Point {
        has $z is ro = 0;

        method clear {
            $self->next::method;
            $z = 0;
        }
    }

=head1 DESCRIPTION

This is a prototype for a new object system for Perl 5.

=head1 The MOP

    class Object {
        method new (%args) { ... }

        method id { ... }

        method can  ($name)  { ... }
        method isa  ($class) { ... }
        method does ($role)  { ... }
        method DOES ($name)  { ... }

        method DESTROY { ... }
    }

    class Attribute extends Object {
        has $name is ro;
        has $default;
        has $storage is ro = {};

        method key_name { ... }

        method has_default   { ... }
        method set_default   { ... }
        method clear_default { ... }
        method get_default   { ... }

        method fetch_data_in_slot_for ($instance) { ... }
        method store_data_in_slot_for ($instance, $data) { ... }
        method store_default_in_slot_for ($instance) { ... }
    }

    class Method extends Object {
        has $name is ro;
        has $body is ro;

        method execute ($invocant, $args) { ... }
    }

    role Role {
        has $name      is ro;
        has $version   is ro;
        has $authority is ro;

        has $roles            is ro = [];
        has $attributes       is ro = {};
        has $methods          is ro = {};
        has $required_methods is ro = {};

        method add_role ($role) { ... }
        method consume_role ($role) { ... }
        method does_role ($name) { ... }

        method attribute_class { 'Attribute' }

        method add_attribute ($attr) { ... }
        method get_attribute ($name) { ... }
        method has_attribute ($name) { ... }

        method method_class { 'Method' }

        method add_method ($attr) { ... }
        method get_method ($name) { ... }
        method has_method ($name) { ... }
        method remove_method ($name) { ... }

        method add_required_method ($required_method) { ... }
        method requires_method ($name) { ... }

        sub FINALIZE { ... }
    }

    class Class extends Object with Role {
        has $superclass  is ro;
        has $submethods  is ro = {};
        has $is_abstract is ro;

        method make_class_abstract { ... }

        method new_instance { ... }

        method submethod_class { 'Method' }

        method add_submethod ($attr) { ... }
        method get_submethod ($name) { ... }
        method has_submethod ($name) { ... }

        method FINALIZE { ... }
    }

=head1 BOOTSTRAPPING GOALS

  Class is an instance of Class
  Object is an instance of Class
  Class is a subclass of Object

  Class does Role
  Role is an instance of Class
  Role does Role

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 AUTHOR

Stevan Little <stevan@iinteractive.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Infinity Interactive.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut



