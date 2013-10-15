package mop::attribute;

use v5.16;
use warnings;

use Scalar::Util qw[ weaken isweak ];

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use parent 'mop::object', 'mop::internals::observable';

mop::internals::util::init_attribute_storage(my %name);
mop::internals::util::init_attribute_storage(my %original_id);
mop::internals::util::init_attribute_storage(my %default);
mop::internals::util::init_attribute_storage(my %storage);
mop::internals::util::init_attribute_storage(my %associated_meta);

# temporary, for bootstrapping
sub new {
    my $class = shift;
    my %args  = @_;
    my $self = $class->SUPER::new;
    $name{ $self }    = \($args{'name'});
    $default{ $self } = \($args{'default'}) if exists $args{'default'};
    $storage{ $self } = \($args{'storage'}) if exists $args{'storage'};
    # NOTE:
    # keep track of the original ID here
    # so that we can still detect attribute
    # conflicts in roles even after something
    # has been cloned
    # - SL
    $original_id{ $self } = \(mop::id($self));

    $self
}

# temporary, for bootstrapping
sub clone {
    my $self = shift;
    return ref($self)->new(
        name => $self->name,
        default => ${ $default{ $self } },
        storage => ${ $storage{ $self } },
    );
}

sub name { ${ $name{ $_[0] } } }

sub key_name {
    my $self = shift;
    substr( $self->name, 2, length $self->name )
}

# NOTE:
# need to do a double de-ref for the
# default value. first is to access
# the value from the attribute, the
# second is to  actually dereference
# the default value (which is stored
# as a ref of whatever the default is)
# - SL
sub has_default { defined( ${ ${ $default{ $_[0] } } } ) }
# we also have to do the double en-ref
# here too, this should get fixed
sub set_default   {
    my $self = shift;
    my ($value) = @_;
    if ( ref $value && ref $value ne 'CODE' ) {
        die "References of type (" . ref($value) . ") are not supported as attribute defaults (in attribute " . $self->name . ($self->associated_meta ? " in class " . $self->associated_meta->name : "") . ")";
    }
    $default{ $self } = \(\$value)
}
sub clear_default { ${ ${ delete $default{ $_[0] } } } }
sub get_default {
    my $self  = shift;
    my $value = ${ ${ $default{ $self } } };
    if ( ref $value && ref $value eq 'CODE' ) {
        $value = $value->();
    }
    $value
}

sub associated_meta { ${ $associated_meta{ $_[0] } } }
sub set_associated_meta {
    my ($self, $meta) = @_;
    $associated_meta{ $self } = \$meta;
    weaken(${ $associated_meta{ $self } });
}

sub conflicts_with { ${ $original_id{ $_[0] } } ne ${ $original_id{ $_[1] } } }
sub locally_defined { ${ $original_id{ $_[0] } } eq mop::id( $_[0] ) }

sub has_data_in_slot_for {
    my ($self, $instance) = @_;
    defined ${ ${ $storage{ $self } }->{ $instance } };
}

sub fetch_data_in_slot_for {
    my ($self, $instance) = @_;
    $self->fire('before:FETCH_DATA', $instance);
    my $val = ${ ${ $storage{ $self } }->{ $instance } || \undef };
    $self->fire('after:FETCH_DATA', $instance);
    return $val;
}

sub store_data_in_slot_for {
    my ($self, $instance, $data) = @_;
    $self->fire('before:STORE_DATA', $instance, \$data);
    ${ $storage{ $self } }->{ $instance } = \$data;
    $self->fire('after:STORE_DATA', $instance, \$data);
    return;
}

sub store_default_in_slot_for {
    my ($self, $instance) = @_;
    $self->store_data_in_slot_for($instance, do {
        local $_ = $instance;
        $self->get_default;
    }) if $self->has_default;
}

sub remove_data_in_slot_for {
    my ($self, $instance) = @_;
    delete ${ $storage{ $self } }->{ $instance };
}

sub weaken_data_in_slot_for {
    my ($self, $instance) = @_;
    weaken(${ ${ $storage{ $self } }->{ $instance } });
}

sub is_data_in_slot_weak_for {
    my ($self, $instance) = @_;
    isweak(${ ${ $storage{ $self } }->{ $instance } });
}

our $METACLASS;

sub __INIT_METACLASS__ {
    return $METACLASS if defined $METACLASS;
    require mop::class;
    $METACLASS = mop::class->new(
        name       => 'mop::attribute',
        version    => $VERSION,
        authority  => $AUTHORITY,
        superclass => 'mop::object'
    );

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!name',
        storage => \%name
    ));

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!original_id',
        storage => \%original_id,
        default => \sub { mop::id($_) },
    ));

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!default',
        storage => \%default
    ));

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!storage',
        storage => \%storage,
        default => \(sub { mop::internals::util::init_attribute_storage(my %x) })
    ));

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!associated_meta',
        storage => \%associated_meta
    ));

    $METACLASS->add_method( mop::method->new( name => 'name',                body => \&name                ) );
    $METACLASS->add_method( mop::method->new( name => 'key_name',            body => \&key_name            ) );

    $METACLASS->add_method( mop::method->new( name => 'has_default',         body => \&has_default         ) );
    $METACLASS->add_method( mop::method->new( name => 'get_default',         body => \&get_default         ) );
    $METACLASS->add_method( mop::method->new( name => 'set_default',         body => \&set_default         ) );
    $METACLASS->add_method( mop::method->new( name => 'clear_default',       body => \&clear_default       ) );

    $METACLASS->add_method( mop::method->new( name => 'storage',             body => \&storage             ) );

    $METACLASS->add_method( mop::method->new( name => 'associated_meta',     body => \&associated_meta     ) );
    $METACLASS->add_method( mop::method->new( name => 'set_associated_meta', body => \&set_associated_meta ) );
    $METACLASS->add_method( mop::method->new( name => 'conflicts_with',      body => \&conflicts_with      ) );
    $METACLASS->add_method( mop::method->new( name => 'locally_defined',     body => \&locally_defined     ) );

    $METACLASS->add_method( mop::method->new( name => 'has_data_in_slot_for',      body => \&has_data_in_slot_for    ) );
    $METACLASS->add_method( mop::method->new( name => 'fetch_data_in_slot_for',    body => \&fetch_data_in_slot_for    ) );
    $METACLASS->add_method( mop::method->new( name => 'store_data_in_slot_for',    body => \&store_data_in_slot_for    ) );
    $METACLASS->add_method( mop::method->new( name => 'store_default_in_slot_for', body => \&store_default_in_slot_for ) );
    $METACLASS->add_method( mop::method->new( name => 'remove_data_in_slot_for',   body => \&remove_data_in_slot_for   ) );
    $METACLASS->add_method( mop::method->new( name => 'weaken_data_in_slot_for',   body => \&weaken_default_in_slot_for ) );
    $METACLASS->add_method( mop::method->new( name => 'is_data_in_slot_weak_for',  body => \&is_data_in_slot_weak_for  ) );
    $METACLASS;
}

1;

__END__

=pod

=head1 NAME

mop::attribute - A meta-object to represent attributes

=head1 DESCRIPTION

TODO

=head1 METHODS

=over 4

=item C<BUILD>

=item C<clone(%overrides)>

=item C<name>

=item C<key_name>

=item C<has_default>

=item C<get_default>

=item C<set_default($default)>

=item C<clear_default>

=item C<storage>

=item C<associated_meta>

=item C<set_associated_meta($meta)>

=item C<conflicts_with($obj)>

=item C<locally_defined>

=item C<has_data_in_slot_for($instance)>

=item C<fetch_data_in_slot_for($instance)>

=item C<store_data_in_slot_for($instance, $data)>

=item C<store_default_in_slot_for($instance)>

=item C<remove_data_in_slot_for($instance)>

=item C<weaken_data_in_slot_for($instance)>

=item C<is_data_in_slot_weak_for($instance)>

=back

=head1 SEE ALSO

=head2 L<Attribute Details|mop::manual::details::attributes>

=head1 BUGS

Since this module is still under development we would prefer to not
use the RT bug queue and instead use the built in issue tracker on
L<Github|http://www.github.com>.

=head2 L<Git Repository|https://github.com/stevan/p5-mop-redux>

=head2 L<Issue Tracker|https://github.com/stevan/p5-mop-redux/issues>

=head1 AUTHOR

Stevan Little <stevan.little@iinteractive.com>

Jesse Luehrs <doy@tozt.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Infinity Interactive.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=for Pod::Coverage
  new

=cut






