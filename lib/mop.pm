package mop;

use v5.16;
use mro;
use warnings;

use Scalar::Util;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

our $BOOTSTRAPPED = 0;

use mop::object;
use mop::class;
use mop::method;
use mop::attribute;

use mop::internals::observable;

use mop::internals::syntax;
use mop::internals::mro;
use mop::internals::util;

use mop::mro;

use mop::traits;
use mop::traits::util;

sub import {
    shift;
    my $pkg = caller;
    mop::internals::syntax->setup_for( $pkg );
    bootstrap();

    my $caller_stash = mop::internals::util::get_stash_for($pkg);
    my $traits_stash = mop::internals::util::get_stash_for('mop::traits');
    foreach my $trait ( @mop::traits::AVAILABLE_TRAITS ) {
        $caller_stash->add_symbol(
            '&' . $trait, $traits_stash->get_symbol('&' . $trait)
        );
    }
}

sub unimport {
    my $pkg = caller;
    mop::internals::util::get_stash_for($pkg)->remove_glob($_)
        for (
            qw(class role method submethod has),
            @mop::traits::AVAILABLE_TRAITS
        );
}

sub meta {
    my $class = shift;
    die "Could not find metaclass for $class"
      unless has_meta( $class );
    find_meta( $class );
}

sub id {
    my $obj = shift;
    die "Could not find an object id for $obj"
      unless is_mop_object($obj);
    get_object_id($obj);
}

sub find_meta {
    ${ mop::internals::util::get_stash_for( shift )->get_symbol('$METACLASS') || \undef }
}

sub has_meta  {
    mop::internals::util::get_stash_for( shift )->has_symbol('$METACLASS')
}

sub remove_meta {
    mop::internals::util::get_stash_for( shift )->remove_symbol('$METACLASS')
}

sub get_object_id { Hash::Util::FieldHash::id( $_[0] ) }

sub is_mop_object {
    defined Hash::Util::FieldHash::id_2obj( get_object_id( $_[0] ) );
}

sub apply_metaclass {
    # TODO: we should really not be calling apply_metaclass at all during
    # bootstrapping, but it's done in a couple places for simplicity, to avoid
    # needing multiple implementations of things for pre- and
    # post-bootstrapping. we should probably eventually actually do the
    # replacement in those methods, to make sure bootstrapping isn't doing
    # unnecessary extra work. the actual implementation is replaced below.
    return;
}

sub rebless {
    my ($object, $into) = @_;

    my $from = Scalar::Util::blessed($object);
    my $common_base = mop::internals::util::find_common_base($from, $into);

    my @from_isa = @{ mop::mro::get_linear_isa($from) };
    if ($common_base) {
        pop @from_isa until $from_isa[-1] eq $common_base;
        pop @from_isa;
    }
    @from_isa = grep { defined } map { find_meta($_) } @from_isa;

    my @into_isa = @{ mop::mro::get_linear_isa($into) };
    if ($common_base) {
        pop @into_isa until $into_isa[-1] eq $common_base;
        pop @into_isa;
    }
    @into_isa = grep { defined } map { find_meta($_) } @into_isa;

    for my $attr (map { $_->attributes } @from_isa) {
        delete $attr->storage->{$object};
    }

    bless($object, $into);

    for my $attr (map { $_->attributes } reverse @into_isa) {
        $attr->store_default_in_slot_for($object);
    }

    $object
}

sub dump_object {
    my ($obj) = @_;

    my %attributes = map {
        if (my $m = find_meta($_)) {
            %{ $m->attribute_map }
        }
    } reverse @{ mop::mro::get_linear_isa($obj) };

    my $temp = {
        __ID__    => id($obj),
        __CLASS__ => meta($obj)->name,
        __SELF__  => $obj,
    };

    foreach my $attr (values %attributes) {
        if ($attr->name eq '$storage') {
            $temp->{ $attr->name } = '__INTERNAL_DETAILS__';
        } else {
            $temp->{ $attr->name } = sub {
                my ($data) = @_;
                if (Scalar::Util::blessed($data)) {
                    return dump_object($data);
                } elsif (ref $data) {
                    if (ref $data eq 'ARRAY') {
                        return [ map { __SUB__->( $_ ) } @$data ];
                    } elsif (ref $data eq 'HASH') {
                        return {
                            map { $_ => __SUB__->( $data->{$_} ) } keys %$data
                        };
                    } else {
                        return $data;
                    }
                } else {
                    return $data;
                }
            }->( $attr->fetch_data_in_slot_for( $obj ) );
        }
    }

    $temp;
}

sub bootstrap {
    return if $BOOTSTRAPPED;
    $_->__INIT_METACLASS__ for qw[
        mop::object
        mop::role
        mop::class
        mop::attribute
        mop::method
        mop::internals::observable
    ];

    my $Object = find_meta('mop::object');

    my $Role  = find_meta('mop::role');
    my $Class = find_meta('mop::class');

    my $Method     = find_meta('mop::method');
    my $Attribute  = find_meta('mop::attribute');
    my $Observable = find_meta('mop::internals::observable');

    # At this point the metaclass
    # layer class to role relationship
    # is correct. And the following
    #   - Class does Role
    #   - Role is instance of Class
    #   - Role does Role
    # is true.
    $Class->add_role( $Role );

    # flatten mop::observable into wherever it's needed (it's just an
    # implementation detail (#95), so it shouldn't end up being directly
    # visible)
    foreach my $meta ( $Role, $Attribute, $Method ) {
        for my $attribute ( $Observable->attributes ) {
            $meta->add_attribute($attribute->clone(associated_meta => $meta));
        }
        for my $method ( $Observable->methods ) {
            $meta->add_method($method->clone(associated_meta => $meta));
        }
    }

    # and now this is no longer needed
    remove_meta('mop::internals::observable');

    foreach my $meta ( $Object, $Method, $Attribute, $Class, $Role ) {
        $meta->FINALIZE;
    }

    {
        my $Object_stash    = mop::internals::util::get_stash_for('mop::object');
        my $Class_stash     = mop::internals::util::get_stash_for('mop::class');
        my $Role_stash      = mop::internals::util::get_stash_for('mop::role');
        my $Method_stash    = mop::internals::util::get_stash_for('mop::method');
        my $Attribute_stash = mop::internals::util::get_stash_for('mop::attribute');

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
        $Attribute_stash->remove_symbol('&clone');

        # replace the temporary implementation of mop::object::new
        my $new = mop::method->new(
            name => 'new',
            body => sub {
                my $class = shift;
                my %args  = scalar(@_) == 1 && ref $_[0] eq 'HASH'
                    ? %{$_[0]}
                    : @_;
                mop::internals::util::find_or_inflate_meta($class)->new_instance(%args);
            },
        );
        $Object->add_method($new);
        $Object_stash->add_symbol('&new', $new->body);

        # remove the temporary constructors used in the bootstrap
        $Class_stash->remove_symbol('&new');
        $Role_stash->remove_symbol('&new');
        $Method_stash->remove_symbol('&new');
        $Attribute_stash->remove_symbol('&new');
    }

    {
        no warnings 'redefine';
        *apply_metaclass = sub {
            my ($instance, $new_meta) = @_;
            rebless $instance, mop::internals::util::fix_metaclass_compatibility($new_meta, $instance);
        };
    }

    {
        my $old_next_method = \&next::method;
        my $old_next_can    = \&next::can;
        no warnings 'redefine';
        *next::method = sub {
            my $invocant = shift;
            if ( has_meta( $invocant ) ) {
                $invocant->mop::next::method( @_ )
            } else {
                $invocant->$old_next_method( @_ )
            }
        };

        *next::can = sub {
            my $invocant = shift;
            if ( has_meta( $invocant ) ) {
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

    class mop::object {
        method new   (%args) { ... }
        method clone (%args) { ... }

        method BUILDALL ($args) { ... }

        method can  ($name)  { ... }
        method isa  ($class) { ... }
        method does ($role)  { ... }
        method DOES ($name)  { ... }

        method DESTROY { ... }
    }

    class mop::attribute extends mop::object {
        has $!name is ro;
        has $!default;
        has $!storage is ro = {};
        has $!associated_meta is ro;
        has $!original_id;

        has $!callbacks;

        method key_name { ... }

        method has_default   { ... }
        method get_default   { ... }

        method set_associated_meta ($meta) { ... }

        method conflicts_with ($attr) { ... }

        method fetch_data_in_slot_for ($instance) { ... }
        method store_data_in_slot_for ($instance, $data) { ... }
        method store_default_in_slot_for ($instance) { ... }

        method bind   ($event_name, $cb) { ... }
        method unbind ($event_name, $cb) { ... }
        method fire   ($event_name) { ... }
    }

    class mop::method extends mop::object {
        has $!name is ro;
        has $!body is ro;
        has $!associated_meta is ro;
        has $!original_id;

        has $!callbacks;

        method execute ($invocant, $args) { ... }

        method set_associated_meta ($meta) { ... }

        method conflicts_with ($method) { ... }

        method bind   ($event_name, $cb) { ... }
        method unbind ($event_name, $cb) { ... }
        method fire   ($event_name) { ... }
    }

    class mop::role extends mop::object {
        has $!name      is ro;
        has $!version   is ro;
        has $!authority is ro;

        has $!roles            is ro = [];
        has $!attributes             = {};
        has $!methods                = {};
        has $!required_methods       = {};

        has $!callbacks;

        method add_role ($role) { ... }
        method does_role ($name) { ... }

        method attribute_class { 'mop::attribute' }

        method attributes { ... }
        method attribute_map { ... }

        method add_attribute ($attr) { ... }
        method get_attribute ($name) { ... }
        method has_attribute ($name) { ... }

        method method_class { 'mop::method' }

        method methods { ... }
        method method_map { ... }

        method add_method ($attr) { ... }
        method get_method ($name) { ... }
        method has_method ($name) { ... }

        method required_methods { ... }
        method required_method_map { ... }

        method add_required_method ($required_method) { ... }
        method remove_required_method ($required_method) { ... }
        method requires_method ($name) { ... }

        method bind   ($event_name, $cb) { ... }
        method unbind ($event_name, $cb) { ... }
        method fire   ($event_name) { ... }

        sub FINALIZE { ... }
    }

    # 'with mop::role' is odd because mop::role is a class, but it works as
    # you would expect
    class mop::class extends mop::object with mop::role {
        has $!superclass is ro;
        has $!submethods = {};
        has $!is_abstract is ro;
        has $!instance_generator is ro = sub { \(my $anon) };

        method make_class_abstract { ... }

        method is_closed { ... }

        method new_instance { ... }
        method clone_instance { ... }

        method set_instance_generator ($generator) { ... }
        method create_fresh_instance_structure { ... }

        method submethod_class { 'mop::method' }

        method submethods { ... }
        method submethod_map { ... }

        method add_submethod ($attr) { ... }
        method get_submethod ($name) { ... }
        method has_submethod ($name) { ... }
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



