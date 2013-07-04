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

=pod

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
  
  class Attribute (extends => 'Object') {
      has $name;
      has $default;
      has $storage = {};
  
      method name { $name }
  
      method key_name { ... }
  
      method has_default { ... }
      method get_default { ... }
  
      method storage { $storage }
  
      method fetch_data_in_slot_for ($instance) { ... }
      method store_data_in_slot_for ($instance, $data) { ... }
      method store_default_in_slot_for ($instance) { ... }
  }
  
  class Method (extends => 'Object') {
      has $name;
      has $body;
  
      method name { $name }
      method body { $body }
  
      method execute ($invocant, $args) { ... }
  }
  
  role Role {
      has $name;
      has $version;
      has $authority;
  
      has $roles            = [];
      has $attributes       = {};
      has $methods          = {};
      has $required_methods = [];
  
      method name      { $name }
      method version   { $version }
      method authority { $authority }
  
      method roles { $roles } 
  
      method add_role ($role) { ... }
      method does_role ($name) { ... }
  
      method attribute_class { 'Attribute' }
  
      method attributes { $attributes }
  
      method add_attribute ($attr) { ... }
      method get_attribute ($name) { ... }
      method has_attribute ($name) { ... }
  
      method method_class { 'Method' }
  
      method methods { $methods }
  
      method add_method ($attr) { ... }
      method get_method ($name) { ... }
      method has_method ($name) { ... }
  
      method required_methods { $required_methods }
  
      method add_required_method ($required_method) { ... }
      method requires_method ($name) { ... }
  
      method compose_into ($other) { ... }
  
      sub FINALIZE { ... }
  }
  
  class Class (extends => 'Object', with => ['Role']) {
      has $superclass;
      has $submethods = {};
  
      method superclass { $superclass }
  
      method is_abstract { ... }
  
      method new_instance { ... }
  
      method submethod_class { 'Method' }
  
      method submethods { $submethods }
  
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
  Role is instance of Class
  Role does Role

=cut








