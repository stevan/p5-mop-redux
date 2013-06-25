package mop::class;

use v5.16;
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

our $METACLASS;

sub metaclass {
    return $METACLASS if defined $METACLASS;
    require mop::class;
    $METACLASS = mop::class->new(
        name       => 'mop::class',
        version    => $VERSION,
        authrority => $AUTHORITY,        
        superclass => 'mop::object'
    );
    $METACLASS->add_method( mop::method->new( name => 'new',        body => \&new        ) );
    $METACLASS->add_method( mop::method->new( name => 'name',       body => \&name       ) );
    $METACLASS->add_method( mop::method->new( name => 'version',    body => \&version    ) );   
    $METACLASS->add_method( mop::method->new( name => 'authority',  body => \&authority  ) );
    $METACLASS->add_method( mop::method->new( name => 'superclass', body => \&superclass ) );

    $METACLASS->add_method( mop::method->new( name => 'attributes',    body => \&attributes    ) );
    $METACLASS->add_method( mop::method->new( name => 'get_attribute', body => \&get_attribute ) );
    $METACLASS->add_method( mop::method->new( name => 'add_attribute', body => \&add_attribute ) );
    $METACLASS->add_method( mop::method->new( name => 'has_attribute', body => \&has_attribute ) );

    $METACLASS->add_method( mop::method->new( name => 'methods',    body => \&methods    ) );
    $METACLASS->add_method( mop::method->new( name => 'get_method', body => \&get_method ) );
    $METACLASS->add_method( mop::method->new( name => 'add_method', body => \&add_method ) );
    $METACLASS->add_method( mop::method->new( name => 'has_method', body => \&has_method ) );

    $METACLASS->add_method( mop::method->new( name => 'submethods',    body => \&submethods    ) );
    $METACLASS->add_method( mop::method->new( name => 'get_submethod', body => \&get_submethod ) );
    $METACLASS->add_method( mop::method->new( name => 'add_submethod', body => \&add_submethod ) );
    $METACLASS->add_method( mop::method->new( name => 'has_submethod', body => \&has_submethod ) );

    $METACLASS;
}

1;

__END__