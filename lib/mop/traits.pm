package mop::traits;

use v5.16;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

our @AVAILABLE_TRAITS = qw[ rw ro abstract overload ];

sub rw {
    my $meta = shift;
    my (%args) = @_;
    if (exists $args{'attribute'}) {
        my ($name, @args) = @{$args{'attribute'}};
        my $attr = $meta->get_attribute($name);
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
}

sub ro {
    my $meta = shift;
    my (%args) = @_;
    if (exists $args{'attribute'}) {
        my ($name, @args) = @{$args{'attribute'}};
        my $attr = $meta->get_attribute($name);
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
}

sub abstract {
    my $meta = shift;
    my (%args) = @_;
    $meta->make_class_abstract;
}

sub overload {
    my $meta = shift;
    my (%args) = @_;

    if (exists $args{'method'}) {
        my ($method_name, $operator) = @{$args{'method'}};
        my $method = $meta->get_method($method_name);

        # NOTE:
        # We are actually installing the overloads
        # into the package directly, this works 
        # because the MRO stuff doesn't actually 
        # get used if the the methods are local 
        # to the package. This should avoid some
        # complexity (perhaps). 

        # don't load it unless you 
        # have too, it adds a speed
        # penalty to the runtime
        require overload;
        overload::OVERLOAD(
            $meta->name, 
            $operator,
            sub { $method->execute( shift( @_ ), [ @_ ] ) }, 
            fallback => 1
        );
    }
}

1;

