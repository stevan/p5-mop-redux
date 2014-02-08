package mop::attribute;

use v5.16;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Scalar::Util qw[ weaken isweak ];
use mop::internals::util;

our $VERSION   = '0.03';
our $AUTHORITY = 'cpan:STEVAN';

use parent 'mop::object', 'mop::internals::observable';

mop::internals::util::init_attribute_storage(my %name);
mop::internals::util::init_attribute_storage(my %default);
mop::internals::util::init_attribute_storage(my %associated_meta);
mop::internals::util::init_attribute_storage(my %original_id);
mop::internals::util::init_attribute_storage(my %storage);

sub name            ($self) { ${ $name{ $self }            // \undef } }
sub associated_meta ($self) { ${ $associated_meta{ $self } // \undef } }

sub set_associated_meta ($self, $meta) {
    $associated_meta{ $self } = \$meta;
    weaken(${ $associated_meta{ $self } });
}

# temporary, for bootstrapping
sub new ($class, %args) {
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

sub BUILD ($self, $) {
    return unless $default{ $self };
    my $value = ${ $default{ $self } };
    if ( ref $value && ref $value ne 'CODE' ) {
        die "References of type (" . ref($value) . ") are not supported as attribute defaults (in attribute " . $self->name . ($self->associated_meta ? " in class " . $self->associated_meta->name : "") . ")";
    }
}

# temporary, for bootstrapping
sub clone ($self, %) {
    return ref($self)->new(
        name => $self->name,
        default => ${ $default{ $self } },
        storage => ${ $storage{ $self } },
    );
}

sub key_name ($self) {
    substr( $self->name, 2, length $self->name )
}

sub has_default ($self) { defined( ${ $default{ $self } } ) }

sub set_default ($self, $value) {
    if ( ref $value && ref $value ne 'CODE' ) {
        die "References of type (" . ref($value) . ") are not supported as attribute defaults (in attribute " . $self->name . ($self->associated_meta ? " in class " . $self->associated_meta->name : "") . ")";
    }
    $default{ $self } = \$value
}

sub clear_default ($self) { ${ delete $default{ $self } } }

sub get_default ($self) {
    my $value = ${ $default{ $self } };
    if ( ref $value && ref $value eq 'CODE' ) {
        $value = $value->();
    }
    $value
}

sub conflicts_with ($self, $other) {
    ${ $original_id{ $self } } ne ${ $original_id{ $other } }
}

sub locally_defined ($self) {
    ${ $original_id{ $self } } eq mop::id( $self )
}

sub has_data_in_slot_for ($self, $instance) {
    defined ${ $self->get_slot_for($instance) };
}

sub fetch_data_in_slot_for ($self, $instance) {
    $self->fire('before:FETCH_DATA', $instance);
    my $val = ${ $self->get_slot_for($instance) };
    $self->fire('after:FETCH_DATA', $instance, \$val);
    return $val;
}

sub store_data_in_slot_for ($self, $instance, $data) {
    $self->fire('before:STORE_DATA', $instance, \$data);
    ${ $self->get_slot_for($instance) } = $data;
    $self->fire('after:STORE_DATA', $instance, \$data);
    return;
}

sub store_default_in_slot_for ($self, $instance) {
    $self->store_data_in_slot_for($instance, do {
        local $_ = $instance;
        $self->get_default;
    }) if $self->has_default;
}

sub weaken_data_in_slot_for ($self, $instance) {
    weaken(${ $self->get_slot_for($instance) });
}

sub is_data_in_slot_weak_for ($self, $instance) {
    isweak(${ $self->get_slot_for($instance) });
}

sub get_slot_for ($self, $instance) {
    ${ $storage{ $self } }->{ $instance } //= \(my $slot);
}

sub __INIT_METACLASS__ ($) {
    my $METACLASS = mop::class->new(
        name       => 'mop::attribute',
        version    => $VERSION,
        authority  => $AUTHORITY,
        superclass => 'mop::object',
    );

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!name',
        storage => \%name,
    ));
    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!default',
        storage => \%default,
    ));
    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!associated_meta',
        storage => \%associated_meta,
    ));
    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!original_id',
        storage => \%original_id,
        default => sub { mop::id($_) },
    ));
    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!storage',
        storage => \%storage,
        default => sub { mop::internals::util::init_attribute_storage(my %x) },
    ));

    $METACLASS->add_method( mop::method->new( name => 'BUILD', body => \&BUILD ) );

    $METACLASS->add_method( mop::method->new( name => 'name',     body => \&name     ) );
    $METACLASS->add_method( mop::method->new( name => 'key_name', body => \&key_name ) );

    $METACLASS->add_method( mop::method->new( name => 'has_default',   body => \&has_default   ) );
    $METACLASS->add_method( mop::method->new( name => 'get_default',   body => \&get_default   ) );
    $METACLASS->add_method( mop::method->new( name => 'set_default',   body => \&set_default   ) );
    $METACLASS->add_method( mop::method->new( name => 'clear_default', body => \&clear_default ) );

    $METACLASS->add_method( mop::method->new( name => 'associated_meta',     body => \&associated_meta     ) );
    $METACLASS->add_method( mop::method->new( name => 'set_associated_meta', body => \&set_associated_meta ) );

    $METACLASS->add_method( mop::method->new( name => 'conflicts_with',  body => \&conflicts_with  ) );
    $METACLASS->add_method( mop::method->new( name => 'locally_defined', body => \&locally_defined ) );

    $METACLASS->add_method( mop::method->new( name => 'has_data_in_slot_for',      body => \&has_data_in_slot_for      ) );
    $METACLASS->add_method( mop::method->new( name => 'fetch_data_in_slot_for',    body => \&fetch_data_in_slot_for    ) );
    $METACLASS->add_method( mop::method->new( name => 'store_data_in_slot_for',    body => \&store_data_in_slot_for    ) );
    $METACLASS->add_method( mop::method->new( name => 'store_default_in_slot_for', body => \&store_default_in_slot_for ) );
    $METACLASS->add_method( mop::method->new( name => 'weaken_data_in_slot_for',   body => \&weaken_data_in_slot_for   ) );
    $METACLASS->add_method( mop::method->new( name => 'is_data_in_slot_weak_for',  body => \&is_data_in_slot_weak_for  ) );
    $METACLASS->add_method( mop::method->new( name => 'get_slot_for',              body => \&get_slot_for              ) );

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

=item C<name>

=item C<key_name>

=item C<has_default>

=item C<get_default>

=item C<set_default($default)>

=item C<clear_default>

=item C<associated_meta>

=item C<set_associated_meta($meta)>

=item C<conflicts_with($obj)>

=item C<locally_defined>

=item C<has_data_in_slot_for($instance)>

=item C<fetch_data_in_slot_for($instance)>

=item C<store_data_in_slot_for($instance, $data)>

=item C<store_default_in_slot_for($instance)>

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

Florian Ragwitz <rafl@debian.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013-2014 by Infinity Interactive.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=for Pod::Coverage
  new
  clone

=cut
