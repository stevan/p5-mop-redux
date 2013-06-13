package mop::attribute;

use strict;
use warnings;

use parent 'mop::object';

sub new {
    my $class = shift;
    my %args  = @_;
    $class->SUPER::new(
        name    => $args{'name'},
        default => $args{'default'}
    );
}

sub name { (shift)->{'name'} }

sub key_name {
    my $self = shift;
    substr( $self->name, 1, length $self->name )
}

sub has_default { defined (shift)->{'default'} }
sub get_default { (shift)->{'default'}->()     }

1;

__END__