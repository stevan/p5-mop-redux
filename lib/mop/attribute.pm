package mop::attribute;

use v5.16;
use warnings;

use Scalar::Util qw[ weaken ];

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

    $self
}

sub BUILD {
    my $self = shift;
    # NOTE:
    # keep track of the original ID here
    # so that we can still detect attribute
    # conflicts in roles even after something
    # has been cloned
    # - SL
    $original_id{ $self } //= \(mop::id($self));
}

# temporary, for bootstrapping
sub clone {
    my $self = shift;
    return ref($self)->new(
        name => $self->name,
        default => ${ $default{ $self } },
        storage => $self->storage,
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
sub set_default   { $default{ $_[0] } = \(\$_[1]) }
sub clear_default { ${ ${ delete $default{ $_[0] } } } }
sub get_default {
    my $self  = shift;
    my $value = ${ ${ $default{ $self } } };
    if ( ref $value  ) {
        if ( ref $value  eq 'CODE' ) {
            $value  = $value->();
        } else {
            die "References of type (" . ref($value) . ") are not supported as attribute defaults (in attribute " . $self->name . ($self->associated_meta ? " in class " . $self->associated_meta->name : "") . ")";
        }
    }
    $value
}

sub storage { ${ $storage{ $_[0] } } }

sub associated_meta { ${ $associated_meta{ $_[0] } } }
sub set_associated_meta {
    my ($self, $meta) = @_;
    $associated_meta{ $self } = \$meta;
    weaken(${ $associated_meta{ $self } });
}

sub conflicts_with { ${ $original_id{ $_[0] } } ne ${ $original_id{ $_[1] } } }

sub has_data_in_slot_for {
    my ($self, $instance) = @_;
    exists $self->storage->{ $instance };
}

sub fetch_data_in_slot_for {
    my ($self, $instance) = @_;
    $self->fire('before:FETCH_DATA', $instance);
    my $val = ${ $self->storage->{ $instance } || \undef };
    $self->fire('after:FETCH_DATA', $instance);
    return $val;
}

sub store_data_in_slot_for {
    my ($self, $instance, $data) = @_;
    $self->fire('before:STORE_DATA', $instance, \$data);
    $self->storage->{ $instance } = \$data;
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
        storage => \%original_id
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

    $METACLASS->add_method( mop::method->new( name => 'BUILD', body => \&BUILD ) );

    $METACLASS->add_method( mop::method->new( name => 'name',                body => \&name                ) );
    $METACLASS->add_method( mop::method->new( name => 'key_name',            body => \&key_name            ) );
    $METACLASS->add_method( mop::method->new( name => 'has_default',         body => \&has_default         ) );
    $METACLASS->add_method( mop::method->new( name => 'get_default',         body => \&get_default         ) );
    $METACLASS->add_method( mop::method->new( name => 'storage',             body => \&storage             ) );
    $METACLASS->add_method( mop::method->new( name => 'associated_meta',     body => \&associated_meta     ) );
    $METACLASS->add_method( mop::method->new( name => 'set_associated_meta', body => \&set_associated_meta ) );
    $METACLASS->add_method( mop::method->new( name => 'conflicts_with',      body => \&conflicts_with      ) );

    $METACLASS->add_method( mop::method->new( name => 'fetch_data_in_slot_for',    body => \&fetch_data_in_slot_for    ) );
    $METACLASS->add_method( mop::method->new( name => 'store_data_in_slot_for',    body => \&store_data_in_slot_for    ) );
    $METACLASS->add_method( mop::method->new( name => 'store_default_in_slot_for', body => \&store_default_in_slot_for ) );
    $METACLASS;
}

1;

__END__

=pod

=head1 NAME

mop::attribute

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






