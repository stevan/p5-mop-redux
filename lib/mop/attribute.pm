package mop::attribute;

use strict;
use warnings;

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
sub get_default { (shift)->{'default'}->()     }

sub storage { (shift)->{'storage'} }

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
    $METACLASS;
}

1;

__END__