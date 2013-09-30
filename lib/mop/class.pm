package mop::class;

use v5.16;
use warnings;

use mop::util qw[ has_meta find_meta apply_metaclass ];
use mop::internals::util;

use Module::Runtime qw[ is_module_name module_notional_filename ];
use Scalar::Util qw[ blessed ];

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use parent 'mop::role';

mop::internals::util::init_attribute_storage(my %is_abstract);
mop::internals::util::init_attribute_storage(my %superclass);
mop::internals::util::init_attribute_storage(my %submethods);
mop::internals::util::init_attribute_storage(my %instance_generator);

sub new {
    my $class = shift;
    my %args  = @_;
    my $self = $class->SUPER::new( @_ );
    $is_abstract{ $self }        = \($args{'is_abstract'} // 0);
    $superclass{ $self }         = \($args{'superclass'});
    $submethods{ $self }         = \({});

    if ($args{'superclass'} && (my $meta = find_meta($args{'superclass'}))) {
        $instance_generator{ $self } = \$meta->instance_generator;

        # merge required methods with superclass
        $self->add_required_method($_)
            for $meta->required_methods;
    }
    else {
        mop::internals::util::mark_nonmop_class($args{'superclass'})
            if $args{'superclass'};

        $instance_generator{ $self } = \(sub { \(my $anon) });
    }

    if ( defined( $args{'name'} ) && is_module_name( $args{'name'} ) ) {
        $INC{ module_notional_filename( $args{'name'} ) } //= '(mop)';
    }

    if (defined(my $super = $self->superclass)) {
        apply_metaclass($self, find_meta($super)) if find_meta($super);
    }

    $self;
}

sub BUILD {
    my $self = shift;

    mop::internals::util::install_meta($self);
}

# identity

sub superclass { ${ $superclass{ $_[0] } } }

sub is_abstract { ${ $is_abstract{ $_[0] } } }

sub make_class_abstract { $is_abstract{ $_[0] } = \1 }

sub is_closed { 0 }

# instance creation

sub new_instance {
    my $self = shift;
    my (%args) = @_;

    die 'Cannot instantiate abstract class (' . $self->name . ')'
        if $self->is_abstract;

    my $instance = bless $self->create_fresh_instance_structure, $self->name;
    mop::internals::util::register_object($instance);

    my %attributes = map {
        if (my $m = find_meta($_)) {
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
            if (my $m = find_meta($_)) {
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
        map { find_meta($_) }
        @{ mop::mro::get_linear_isa($self->name) }
    );
    shift @super_methods;
    @super_methods = grep { defined } @super_methods;

    if (my $super = $super_methods[0]) {
        apply_metaclass($method, $super);
    }

    $self->mop::role::add_method($method);
}

# submethods

sub submethod_class { 'mop::method' }

sub submethod_map { ${ $submethods{ $_[0] } } }

sub submethods { values %{ $_[0]->submethod_map } }

sub add_submethod {
    my ($self, $submethod) = @_;
    $self->submethod_map->{ $submethod->name } = $submethod;
}

sub get_submethod {
    my ($self, $name) = @_;
    $self->submethod_map->{ $name }
}

sub has_submethod {
    my ($self, $name) = @_;
    exists $self->submethod_map->{ $name };
}

# events

sub FINALIZE {
    my $self = shift;
    $self->fire('before:FINALIZE');

    mop::util::apply_all_roles($self, @{ $self->roles })
        if @{ $self->roles };

    if ($self->required_methods && not $self->is_abstract) {
        die 'Required method(s) ['
            . (join ', ' => $self->required_methods)
            . '] are not allowed in '
            . $self->name
            . ' unless class is declared abstract';
    }

    my $stash = mop::internals::util::get_stash_for($self->name);
    $stash->add_symbol('$VERSION', \$self->version);

    $self->fire('after:FINALIZE');
}

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
        name    => '$!submethods',
        storage => \%submethods,
        default => \sub { {} },
    ));

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!instance_generator',
        storage => \%instance_generator,
        default => \sub { sub { \(my $anon) } },
    ));

    $METACLASS->add_submethod( mop::method->new( name => 'BUILD', body => \&BUILD ) );

    $METACLASS->add_method( mop::method->new( name => 'new', body => \&new ) );

    $METACLASS->add_method( mop::method->new( name => 'superclass', body => \&superclass ) );

    $METACLASS->add_method( mop::method->new( name => 'is_abstract',         body => \&is_abstract ) );
    $METACLASS->add_method( mop::method->new( name => 'make_class_abstract', body => \&make_class_abstract ) );

    $METACLASS->add_method( mop::method->new( name => 'is_closed',         body => \&is_closed ) );

    $METACLASS->add_method( mop::method->new( name => 'new_instance', body => \&new_instance ) );
    $METACLASS->add_method( mop::method->new( name => 'clone_instance', body => \&clone_instance ) );
    $METACLASS->add_method( mop::method->new( name => 'instance_generator', body => \&instance_generator ) );
    $METACLASS->add_method( mop::method->new( name => 'set_instance_generator', body => \&set_instance_generator ) );
    $METACLASS->add_method( mop::method->new( name => 'create_fresh_instance_structure', body => \&create_fresh_instance_structure ) );

    $METACLASS->add_method( mop::method->new( name => 'submethod_class', body => \&submethod_class ) );
    $METACLASS->add_method( mop::method->new( name => 'submethod_map',   body => \&submethod_map   ) );
    $METACLASS->add_method( mop::method->new( name => 'submethods',      body => \&submethods      ) );
    $METACLASS->add_method( mop::method->new( name => 'get_submethod',   body => \&get_submethod   ) );
    $METACLASS->add_method( mop::method->new( name => 'add_submethod',   body => \&add_submethod   ) );
    $METACLASS->add_method( mop::method->new( name => 'has_submethod',   body => \&has_submethod   ) );

    $METACLASS->add_method( mop::method->new( name => 'FINALIZE', body => \&FINALIZE ) );

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





