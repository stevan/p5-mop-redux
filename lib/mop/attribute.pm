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

our $__META__;

sub meta {
    return $__META__ if defined $__META__;
    require mop::class;
    $__META__ = mop::class->new(
        name       => 'mop::attribute',
        version    => $VERSION,
        authrority => $AUTHORITY,
        superclass => 'mop::object'
    );
    $__META__->add_method( mop::method->new( name => 'new',         body => \&new         ) );
    $__META__->add_method( mop::method->new( name => 'name',        body => \&name        ) );
    $__META__->add_method( mop::method->new( name => 'key_name',    body => \&key_name    ) );   
    $__META__->add_method( mop::method->new( name => 'has_default', body => \&has_default ) );
    $__META__->add_method( mop::method->new( name => 'get_default', body => \&get_default ) );
    $__META__;
}

1;

__END__