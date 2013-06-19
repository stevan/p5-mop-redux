package mop::class;

use strict;
use warnings;

use parent 'mop::object';

sub new {
    my $class = shift;
    my %args  = @_;
    $class->SUPER::new(
        name       => $args{'name'},
        version    => $args{'version'},        
        authority  => $args{'authority'},
        superclass => $args{'superclass'},
        attributes => {},
        methods    => {},
        submethods => {},
    );
}

# identity

sub name       { (shift)->{'name'}       }
sub version    { (shift)->{'version'}    }
sub authority  { (shift)->{'authority'}  }
sub superclass { (shift)->{'superclass'} }

# attributes

sub attributes { (shift)->{'attributes'} }

sub add_attribute {
    my ($self, $attr) = @_;
    $self->{'attributes'}->{ $attr->name } = $attr;
}

sub get_attribute {
    my ($self, $name) = @_;
    $self->{'attributes'}->{ $name }
}

sub has_attribute {
    my ($self, $name) = @_;
    exists $self->{'attributes'}->{ $name };
}

# methods

sub methods { (shift)->{'methods'} }

sub add_method {
    my ($self, $method) = @_;
    $self->{'methods'}->{ $method->name } = $method;
}

sub get_method {
    my ($self, $name) = @_;
    $self->{'methods'}->{ $name }
}

sub has_method {
    my ($self, $name) = @_;
    exists $self->{'methods'}->{ $name };
}

# submethods

sub submethods { (shift)->{'submethods'} }

sub add_submethod {
    my ($self, $submethod) = @_;
    $self->{'submethods'}->{ $submethod->name } = $submethod;
}

sub get_submethod {
    my ($self, $name) = @_;
    $self->{'submethods'}->{ $name }
}

sub has_submethod {
    my ($self, $name) = @_;
    exists $self->{'submethods'}->{ $name };
}

1;

__END__