package mop::attribute;

use v5.16;
use warnings;

use Clone ();

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use parent 'mop::object';

sub new {
    my $class = shift;
    my %args  = @_;
    $class->SUPER::new(
        name    => $args{'name'},
        default => $args{'default'},
        storage => $args{'storage'},
    );
}

sub name { (shift)->{'name'} }

sub key_name {
    my $self = shift;
    substr( $self->name, 1, length $self->name )
}

sub has_default { defined((shift)->{'default'}) }
sub get_default {
    my $self  = shift;
    my $value = ${ $self->{'default'} };
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

sub storage { (shift)->{'storage'} }

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
        authrority => $AUTHORITY,
        superclass => 'mop::object'
    );
    $METACLASS->add_method( mop::method->new( name => 'new',         body => \&new         ) );
    $METACLASS->add_method( mop::method->new( name => 'name',        body => \&name        ) );
    $METACLASS->add_method( mop::method->new( name => 'key_name',    body => \&key_name    ) );   
    $METACLASS->add_method( mop::method->new( name => 'has_default', body => \&has_default ) );
    $METACLASS->add_method( mop::method->new( name => 'get_default', body => \&get_default ) );
    $METACLASS->add_method( mop::method->new( name => 'storage',     body => \&storage     ) );

    $METACLASS->add_method( mop::method->new( name => 'store_data_in_slot_for',    body => \&store_data_in_slot_for    ) );
    $METACLASS->add_method( mop::method->new( name => 'store_default_in_slot_for', body => \&store_default_in_slot_for ) );
    $METACLASS;
}

1;

__END__