package mop::traits;

use v5.16;
use warnings;

our $VERSION   = '0.02';
our $AUTHORITY = 'cpan:STEVAN';

our @available_traits = qw[
    rw
    ro
    required
    weak_ref
    lazy
    abstract
    overload
    extending_non_mop
    repr
];

sub setup_for {
    my ($pkg) = @_;

    mop::internals::util::install_sub($pkg, 'mop::traits', $_)
        for @available_traits;
}

sub teardown_for {
    my ($pkg) = @_;

    mop::internals::util::uninstall_sub($pkg, $_)
        for @available_traits;
}

sub rw {
    my ($attr) = @_;

    die "rw trait is only valid on attributes"
        unless $attr->isa('mop::attribute');

    my $meta = $attr->associated_meta;
    $meta->add_method(
        $meta->method_class->new(
            name => $attr->key_name,
            body => sub {
                my $self = shift;
                $attr->store_data_in_slot_for($self, shift) if @_;
                $attr->fetch_data_in_slot_for($self);
            }
        )
    );
}

sub ro {
    my ($attr) = @_;

    die "ro trait is only valid on attributes"
        unless $attr->isa('mop::attribute');

    my $meta = $attr->associated_meta;
    $meta->add_method(
        $meta->method_class->new(
            name => $attr->key_name,
            body => sub {
                my $self = shift;
                die "Cannot assign to a read-only accessor" if @_;
                $attr->fetch_data_in_slot_for($self);
            }
        )
    );
}

sub required {
    my ($attr) = @_;

    die "required trait is only valid on attributes"
        unless $attr->isa('mop::attribute');

    die "in '" . $attr->name . "' attribute definition: "
      . "'required' trait is incompatible with default value"
        if $attr->has_default;

    $attr->set_default(sub { die "'" . $attr->name . "' is required" });
}

sub abstract {
    my ($class) = @_;

    die "abstract trait is only valid on classes"
        unless $class->isa('mop::class');

    $class->make_class_abstract;
}

sub overload {
    my ($method, $operator) = @_;

    die "overload trait is only valid on methods"
        unless $method->isa('mop::method');

    my $method_name = $method->name;

    # NOTE:
    # This installs the methods into the package
    # directly, rather than going through the
    # mop. This is because overload methods
    # (with their weird names) should probably
    # not show up in the list of methods and such.

    overload::OVERLOAD(
        $method->associated_meta->name,
        $operator,
        sub {
            my $self = shift;
            $self->$method_name(@_)
        },
        fallback => 1
    );
}

sub weak_ref {
    my ($attr) = @_;

    die "weak_ref trait is only valid on attributes"
        unless $attr->isa('mop::attribute');

    $attr->bind('after:STORE_DATA' => sub {
        my (undef, $instance) = @_;
        $attr->weaken_data_in_slot_for($instance);
    });
}

sub lazy {
    my ($attr) = @_;

    die "lazy trait is only valid on attributes"
        unless $attr->isa('mop::attribute');

    my $default = $attr->clear_default;
    $attr->bind('before:FETCH_DATA' => sub {
        my (undef, $instance) = @_;
        if ( !$attr->has_data_in_slot_for($instance) ) {
            $attr->store_data_in_slot_for($instance, do {
                local $_ = $instance;
                ref($default) ? $default->() : $default
            });
        }
    });
}

sub extending_non_mop {
    my ($class, $constructor_name) = @_;

    die "extending_non_mop trait is only valid on classes"
        unless $class->isa('mop::class');

    $constructor_name //= 'new';
    my $super_constructor = join '::' => $class->superclass, $constructor_name;

    $class->add_method(
        $class->method_class->new(
            name => $constructor_name,
            body => sub {
                my $class = shift;
                my $self  = $class->$super_constructor( @_ );
                mop::internals::util::register_object( $self );

                my %attributes = map {
                    if (my $m = mop::meta($_)) {
                        %{ $m->attribute_map }
                    }
                    else {
                        ()
                    }
                } reverse @{ mro::get_linear_isa($class) };

                foreach my $attr (values %attributes) {
                    $attr->store_default_in_slot_for( $self );
                }

                mop::internals::util::buildall($self, @_);

                $self;
            }
        )
    );
}

sub repr {
    my ($class, $instance) = @_;

    die "repr trait is only valid on classes"
        unless $class->isa('mop::class');

    my $generator;
    if (ref $instance && ref $instance eq 'CODE') {
        $generator = $instance;
    }
    elsif (!ref $instance) {
        if ($instance eq 'SCALAR') {
            $generator = sub { \(my $anon) };
        }
        elsif ($instance eq 'ARRAY') {
            $generator = sub { [] };
        }
        elsif ($instance eq 'HASH') {
            $generator = sub { {} };
        }
        elsif ($instance eq 'GLOB') {
            $generator = sub { select select my $fh; %{*$fh} = (); $fh };
        }
        else {
            die "unknown instance generator type $instance";
        }
    }
    else {
        die "unknown instance generator $instance";
    }

    $class->set_instance_generator($generator);
}

1;

__END__

=pod

=head1 NAME

mop::traits - collection of traits for the mop

=head1 DESCRIPTION

This package contains the core traits provided by the mop.

=head1 TRAITS

=head2 C<rw>

When applied to an attribute this will generate a read/write
accessor for that attribute.

It has no effect if it is applied to classes or methods.

=head2 C<ro>

When applied to an attribute this will generate a read-only
accessor for that attribute.

This will throw an exception if it is applied to classes or methods.

=head2 C<required>

When applied to an attribute this will result in a requirement
that a value for this attribute be supplied via the constructor
at instance creation time.

This will throw an exception if the attribute already has a
default value associated with it.

This will throw an exception if it is applied to classes or methods.

=head2 C<weak_ref>

When applied to an attribute this will result in the weakening
of any value stored there.

This will throw an exception if it is applied to classes or methods.

=head2 C<lazy>

When applied to an attribute this will result in the deferred
initialization of the default value of this attribute.

This will throw an exception if it is applied to classes or methods.

=head2 C<abstract>

When applied to a class this will mark the class as being
abstract. It is required to use this trait if your class has
any required methods in it.

This will throw an exception if it is applied to attributes or methods.

=head2 C<overload($operator)>

When applied to a method this will use Perl's built in operator
overloading to associate this method with the specified
C<$operator>. For more information about what kind of overload
behaviors are supported see the L<overload module documentation|overload>.

This will throw an exception if it is applied to classes or attributes.

=head2 C<extending_non_mop>

When applied to a class, whose superclass is a non-MOP class, this
will attempt to ensure that both the superclass's constructor is
called as well as the necessary initialization of the MOP class.
Note that this is a temporary measure until we can make this Just
Work automatically.

This will throw an exception if it is applied to attributes or methods.

=head2 C<repr($ref_type)>

When applied to a class this will use the specified C<$ref_type>
as the underlying instance type for all instances of the class.
Currently supported reference types as SCALAR, ARRAY, HASH and
GLOB, and must be passed as those literal string. If a CODE
reference is passed, it will be directly used by the mop to
generate new instances.

This will throw an exception if it is applied to attributes
or methods.

=head1 SEE ALSO

=head2 L<Traits Manual|mop::manual::details::traits>

=head2 L<mop::traits::util>

=head1 BUGS

Since this module is still under development we would prefer to not
use the RT bug queue and instead use the built in issue tracker on
L<Github|http://www.github.com>.

=head2 L<Git Repository|https://github.com/stevan/p5-mop-redux>

=head2 L<Issue Tracker|https://github.com/stevan/p5-mop-redux/issues>

=head1 AUTHOR

Stevan Little <stevan.little@iinteractive.com>

Jesse Luehrs <doy@tozt.net>

Florian Ragwitz <rafl@debian.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Infinity Interactive.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=for Pod::Coverage
  setup_for
  teardown_for

=cut



