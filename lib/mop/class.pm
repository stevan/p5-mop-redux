package mop::class;

use strict;
use warnings;

use parent 'mop::object';

sub new {
    my $class = shift;
    my %args  = @_;
    bless {
        name       => $args{'name'},
        version    => $args{'version'},        
        authority  => $args{'authority'},
        superclass => $args{'superclass'},
        attributes => {},
        methods    => {},
    } => $class;
}

# identity

sub name       { (shift)->{'name'}       }
sub version    { (shift)->{'version'}    }
sub authority  { (shift)->{'authority'}  }
sub superclass { (shift)->{'superclass'} }

# attributes

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

1;

__END__