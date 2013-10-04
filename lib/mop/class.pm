package mop::class;

use v5.16;
use warnings;

use mop::internals::util;

use Module::Runtime qw[ is_module_name module_notional_filename ];

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use parent 'mop::role';

mop::internals::util::init_attribute_storage(my %is_abstract);
mop::internals::util::init_attribute_storage(my %superclass);
mop::internals::util::init_attribute_storage(my %instance_generator);

# temporary, for bootstrapping
sub new {
    my $class = shift;
    my %args  = @_;

    my $self = $class->SUPER::new( @_ );

    $is_abstract{ $self }        = \($args{'is_abstract'} // 0);
    $superclass{ $self }         = \($args{'superclass'});
    $instance_generator{ $self } = \(sub { \(my $anon) });

    $self;
}

sub BUILD {
    my $self = shift;

    mop::internals::util::install_meta($self);

    if ($self->superclass && (my $meta = mop::meta($self->superclass))) {
        $self->set_instance_generator($meta->instance_generator);

        # merge required methods with superclass
        $self->add_required_method($_)
            for $meta->required_methods;

        mop::apply_metaclass($self, $meta);
    }
    else {
        mop::internals::util::mark_nonmop_class($self->superclass)
            if $self->superclass;
    }

    if ( defined($self->name) && is_module_name($self->name) ) {
        $INC{ module_notional_filename($self->name) } //= '(mop)';
    }
}

# identity

sub superclass { ${ $superclass{ $_[0] } // \undef } }

sub is_abstract { ${ $is_abstract{ $_[0] } } }

sub make_class_abstract { $is_abstract{ $_[0] } = \1 }

# instance creation

sub new_instance {
    my $self = shift;
    my (%args) = @_;

    die 'Cannot instantiate abstract class (' . $self->name . ')'
        if $self->is_abstract;

    my $instance = bless $self->create_fresh_instance_structure, $self->name;
    mop::internals::util::register_object($instance);

    my %attributes = map {
        if (my $m = mop::meta($_)) {
            %{ $m->attribute_map }
        }
    } reverse @{ mop::mro::get_linear_isa($self->name) };

    foreach my $attr (values %attributes) {
        if ( exists $args{ $attr->key_name }) {
            $attr->store_data_in_slot_for( $instance, $args{ $attr->key_name } )
        } else {
            $attr->store_default_in_slot_for( $instance );
        }
    }

    $instance->BUILDALL( \%args );

    return $instance;
}

sub clone_instance {
    my $self = shift;
    my ($instance, %args) = @_;

    my $attributes = {
        map {
            if (my $m = mop::meta($_)) {
                %{ $m->attribute_map }
            }
        } reverse @{ mop::mro::get_linear_isa($self->name) }
    };

    %args = (
        (map {
            my $attr = $attributes->{$_};
            $attr->has_data_in_slot_for($instance)
                ? ($attr->key_name => $attr->fetch_data_in_slot_for($instance))
                : ()
        } grep {
            !exists $args{ $_ }
        } keys %$attributes),
        %args,
    );

    my $clone = $self->new_instance(%args);

    return $clone;
}

sub instance_generator { ${ $instance_generator{ $_[0] } } }
sub set_instance_generator { $instance_generator{ $_[0] } = \$_[1] }

sub create_fresh_instance_structure { (shift)->instance_generator->() }

# methods

sub add_method {
    my $self = shift;
    my ($method) = @_;

    my @super_methods = (
        map { $_ ? $_->get_method($method->name) : undef }
        map { mop::meta($_) }
        @{ mop::mro::get_linear_isa($self->name) }
    );
    shift @super_methods;
    @super_methods = grep { defined } @super_methods;

    if (my $super = $super_methods[0]) {
        mop::apply_metaclass($method, $super);
    }

    $self->mop::role::add_method($method);
}

# events

our $METACLASS;

sub __INIT_METACLASS__ {
    return $METACLASS if defined $METACLASS;
    require mop::class;
    $METACLASS = mop::class->new(
        name       => 'mop::class',
        version    => $VERSION,
        authority  => $AUTHORITY,
        superclass => 'mop::object'
    );

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!is_abstract',
        storage => \%is_abstract,
        default => \(0)
    ));

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!superclass',
        storage => \%superclass
    ));

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!instance_generator',
        storage => \%instance_generator,
        default => \sub { sub { \(my $anon) } },
    ));

    $METACLASS->add_method( mop::method->new( name => 'BUILD', body => \&BUILD ) );


    $METACLASS->add_method( mop::method->new( name => 'superclass', body => \&superclass ) );

    $METACLASS->add_method( mop::method->new( name => 'is_abstract',         body => \&is_abstract ) );
    $METACLASS->add_method( mop::method->new( name => 'make_class_abstract', body => \&make_class_abstract ) );

    $METACLASS->add_method( mop::method->new( name => 'new_instance', body => \&new_instance ) );
    $METACLASS->add_method( mop::method->new( name => 'clone_instance', body => \&clone_instance ) );
    $METACLASS->add_method( mop::method->new( name => 'instance_generator', body => \&instance_generator ) );
    $METACLASS->add_method( mop::method->new( name => 'set_instance_generator', body => \&set_instance_generator ) );
    $METACLASS->add_method( mop::method->new( name => 'create_fresh_instance_structure', body => \&create_fresh_instance_structure ) );

    $METACLASS->add_method( mop::method->new( name => 'add_method', body => \&add_method ) );

    $METACLASS;
}

1;

__END__

=pod

=head1 NAME

mop::class

=head1 DESCRIPTION

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





