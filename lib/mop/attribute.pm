package mop::attribute;

use v5.16;
use warnings;

use mop::util qw[ init_attribute_storage ];
use Clone ();

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use parent 'mop::object';

init_attribute_storage(my %__name_STORAGE);
init_attribute_storage(my %__default_STORAGE);
init_attribute_storage(my %__storage_STORAGE);

sub new {
    my $class = shift;
    my %args  = @_;
    my $self = $class->SUPER::new;
    $__name_STORAGE{ $self }    = \($args{'name'});
    $__default_STORAGE{ $self } = \($args{'default'}) if exists $args{'default'};
    $__storage_STORAGE{ $self } = \($args{'storage'});
    $self
}

sub name { ${ $__name_STORAGE{ $_[0] } } }

sub key_name {
    my $self = shift;
    substr( $self->name, 1, length $self->name )
}

sub has_default { defined( ${ $__default_STORAGE{ $_[0] } }) }
sub get_default {
    my $self  = shift;
    # NOTE:
    # need to do a double de-ref here
    # first is to access the value from
    # the attribute, the second is to 
    # actually dereference the default 
    # value (which is stored as a ref
    # of whatever the default is)
    # - SL
    my $value = ${ ${ $__default_STORAGE{ $self } } };
    if ( ref $value  ) {
        if ( ref $value  eq 'ARRAY' || ref $value  eq 'HASH' ) {
            $value  = Clone::clone( $value  );
        }
        elsif ( ref $value  eq 'CODE' ) {
            $value  = $value ->();
        }
        else {
            die "References of type(" . ref $value  . ") are not supported";
        }
    }
    $value 
}

sub storage { ${ $__storage_STORAGE{ $_[0] } } }

sub fetch_data_in_slot_for {
    my ($self, $instance) = @_;
    ${ $self->storage->{ $instance } || \undef };
}

sub store_data_in_slot_for {
    my ($self, $instance, $data) = @_;
    $self->storage->{ $instance } = \$data;
}

sub store_default_in_slot_for {
    my ($self, $instance) = @_;
    $self->storage->{ $instance } = \($self->get_default)
        if $self->has_default;
}

our $METACLASS;

sub metaclass {
    return $METACLASS if defined $METACLASS;
    require mop::class;
    $METACLASS = mop::class->new(
        name       => 'mop::attribute',
        version    => $VERSION,
        authority  => $AUTHORITY,
        superclass => 'mop::object'
    );

    $METACLASS->add_attribute(mop::attribute->new( 
        name    => '$name', 
        storage => \%__name_STORAGE
    ));

    $METACLASS->add_attribute(mop::attribute->new( 
        name    => '$default', 
        storage => \%__default_STORAGE
    ));

    $METACLASS->add_attribute(mop::attribute->new( 
        name    => '$storage', 
        storage => \%__storage_STORAGE
    ));

    # NOTE:
    # we do not include the new method, because
    # we want all meta-extensions to use the one
    # from mop::object.
    # - SL
    $METACLASS->add_method( mop::method->new( name => 'name',        body => \&name        ) );
    $METACLASS->add_method( mop::method->new( name => 'key_name',    body => \&key_name    ) );   
    $METACLASS->add_method( mop::method->new( name => 'has_default', body => \&has_default ) );
    $METACLASS->add_method( mop::method->new( name => 'get_default', body => \&get_default ) );
    $METACLASS->add_method( mop::method->new( name => 'storage',     body => \&storage     ) );

    $METACLASS->add_method( mop::method->new( name => 'fetch_data_in_slot_for',    body => \&fetch_data_in_slot_for    ) );
    $METACLASS->add_method( mop::method->new( name => 'store_data_in_slot_for',    body => \&store_data_in_slot_for    ) );
    $METACLASS->add_method( mop::method->new( name => 'store_default_in_slot_for', body => \&store_default_in_slot_for ) );
    $METACLASS;
}

1;

__END__