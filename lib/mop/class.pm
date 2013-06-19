package mop::class;

use strict;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

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

our $__META__;

sub meta {
    return $__META__ if defined $__META__;
    require mop::class;
    $__META__ = mop::class->new(
        name       => 'mop::class',
        version    => $VERSION,
        authrority => $AUTHORITY,        
        superclass => 'mop::object'
    );
    $__META__->add_method( mop::method->new( name => 'new',        body => \&new        ) );
    $__META__->add_method( mop::method->new( name => 'name',       body => \&name       ) );
    $__META__->add_method( mop::method->new( name => 'version',    body => \&version    ) );   
    $__META__->add_method( mop::method->new( name => 'authority',  body => \&authority  ) );
    $__META__->add_method( mop::method->new( name => 'superclass', body => \&superclass ) );

    $__META__->add_method( mop::method->new( name => 'attributes',    body => \&attributes    ) );
    $__META__->add_method( mop::method->new( name => 'get_attribute', body => \&get_attribute ) );
    $__META__->add_method( mop::method->new( name => 'add_attribute', body => \&add_attribute ) );
    $__META__->add_method( mop::method->new( name => 'has_attribute', body => \&has_attribute ) );

    $__META__->add_method( mop::method->new( name => 'methods',    body => \&methods    ) );
    $__META__->add_method( mop::method->new( name => 'get_method', body => \&get_method ) );
    $__META__->add_method( mop::method->new( name => 'add_method', body => \&add_method ) );
    $__META__->add_method( mop::method->new( name => 'has_method', body => \&has_method ) );

    $__META__->add_method( mop::method->new( name => 'submethods',    body => \&submethods    ) );
    $__META__->add_method( mop::method->new( name => 'get_submethod', body => \&get_submethod ) );
    $__META__->add_method( mop::method->new( name => 'add_submethod', body => \&add_submethod ) );
    $__META__->add_method( mop::method->new( name => 'has_submethod', body => \&has_submethod ) );

    $__META__;
}

1;

__END__