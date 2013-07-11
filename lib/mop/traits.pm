package mop::traits;

use v5.16;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

our @AVAILABLE_TRAITS = qw[ rw ro abstract ];

sub rw {
    my $meta = shift;
    my (%args) = @_;
    if (my $name = $args{'attribute'}) {
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
    if (my $name = $args{'attribute'}) {
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

1;

