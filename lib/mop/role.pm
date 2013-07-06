package mop::role;

use v5.16;
use warnings;

use mop::util qw[ init_attribute_storage ];

use List::AllUtils qw[ uniq ];

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

init_attribute_storage(my %__name_STORAGE);
init_attribute_storage(my %__version_STORAGE);
init_attribute_storage(my %__authority_STORAGE);

init_attribute_storage(my %__roles_STORAGE);
init_attribute_storage(my %__attributes_STORAGE);
init_attribute_storage(my %__methods_STORAGE);
init_attribute_storage(my %__required_methods_STORAGE);

sub new {
    my $class = shift;
    my %args  = @_;

    # NOTE:
    # the only method from mop::object
    # that we actually used was the 
    # part of &mop::object::new that 
    # created the instance. So since 
    # we really didn't need mop::role
    # to be a subclass of mop::object, 
    # it was easier to just do this 
    # here. 
    # If for some reason, at a later
    # date, this does not work out,
    # we can simply restore the isa
    # relationship, but for now, the 
    # tests pass and it feels right.
    # - SL
    my $self = bless \(my $x) => $class; 

    $__name_STORAGE{ $self }       = \($args{'name'});
    $__version_STORAGE{ $self }    = \($args{'version'});
    $__authority_STORAGE{ $self }  = \($args{'authority'});

    $__roles_STORAGE{ $self }            = \($args{'roles'} || []);
    $__attributes_STORAGE{ $self }       = \({});
    $__methods_STORAGE{ $self }          = \({});
    $__required_methods_STORAGE{ $self } = \([]);

    $self;
}

# identity

sub name       { ${ $__name_STORAGE{ $_[0] } } }
sub version    { ${ $__version_STORAGE{ $_[0] } } }
sub authority  { ${ $__authority_STORAGE{ $_[0] } } }

# roles

sub roles { ${ $__roles_STORAGE{ $_[0] } } }

sub add_role {
    my ($self, $role) = @_;
    push @{ $self->roles } => $role;
}

sub does_role {
    my ($self, $name) = @_;
    foreach my $role ( @{ $self->roles } ) {
        return 1 if $role->name eq $name
                 || $role->does_role( $name );
    }
    return 0;
}

# attributes

sub attribute_class { 'mop::attribute' }

sub attributes { ${ $__attributes_STORAGE{ $_[0] } } }

sub add_attribute {
    my ($self, $attr) = @_;
    $self->attributes->{ $attr->name } = $attr;
}

sub get_attribute {
    my ($self, $name) = @_;
    $self->attributes->{ $name }
}

sub has_attribute {
    my ($self, $name) = @_;
    exists $self->attributes->{ $name };
}

# methods

sub method_class { 'mop::method' }

sub methods { ${ $__methods_STORAGE{ $_[0] } } }

sub add_method {
    my ($self, $method) = @_;
    $self->methods->{ $method->name } = $method;
}

sub get_method {
    my ($self, $name) = @_;
    $self->methods->{ $name }
}

sub has_method {
    my ($self, $name) = @_;
    exists $self->methods->{ $name };
}

sub remove_method {
    my ($self, $name) = @_;
    delete $self->methods->{ $name };
}

# required methods

sub required_methods { ${ $__required_methods_STORAGE{ $_[0] } } }

sub add_required_method {
    my ($self, $required_method) = @_;
    push @{ $self->required_methods } => $required_method;
}

sub requires_method {
    my ($self, $name) = @_;
    scalar grep { $_ eq $name } @{ $self->required_methods };
}

# composition

sub compose_into {
    my ($self, $other) = @_;

    foreach my $attribute (values %{ $self->attributes }) {
        die 'Attribute conflict ' . $attribute->name . ' when composing ' . $self->name . ' into ' . $other->name
            if $other->has_attribute( $attribute->name );
        $other->add_attribute( $attribute );
    }

    foreach my $method (values %{ $self->methods }) {
        # FIXME:
        # These are bootstrap special cases 
        # that need to be fixed. But for now
        # we can just punt.
        # - SL
        next if $method->name eq 'metaclass'
             || $method->name eq 'FINALIZE'; 

        if ($other->isa('mop::role')) {
            if ($other->has_method( $method->name )) {
                $other->add_required_method( $method->name );
                $other->remove_method( $method->name );
            } else {
                $other->add_method( $method );
            }
        } elsif ($other->isa('mop::class')) {
            $other->add_method( $method )
                unless $other->has_method( $method->name );
        }

    }

    # merge required methods ...
    @{ $other->required_methods } = uniq(
        @{ $self->required_methods }, 
        @{ $other->required_methods }
    );
}

# events

sub FINALIZE {
    my $self = shift;

    my $composite = mop::role->new( 
        name => 'COMPOSITE::' . (join '->' => map { $_->name } @{ $self->roles })
    );

    foreach my $role ( @{ $self->roles } ) {
        $role->compose_into( $composite );
    }

    $composite->compose_into( $self );

    # rectify required methods 
    # after composition
    @{ $self->required_methods } = grep { 
        !$self->has_method( $_ )
    } @{ $self->required_methods };
}

our $METACLASS;

sub metaclass {
    return $METACLASS if defined $METACLASS;
    require mop::class;
    $METACLASS = mop::class->new(
        name       => 'mop::role',
        version    => $VERSION,
        authority  => $AUTHORITY,        
        superclass => 'mop::object'
    );

    $METACLASS->add_attribute(mop::attribute->new( 
        name    => '$name', 
        storage => \%__name_STORAGE
    ));

    $METACLASS->add_attribute(mop::attribute->new( 
        name    => '$version', 
        storage => \%__version_STORAGE
    ));

    $METACLASS->add_attribute(mop::attribute->new( 
        name    => '$authority', 
        storage => \%__authority_STORAGE
    ));

    $METACLASS->add_attribute(mop::attribute->new( 
        name    => '$roles', 
        storage => \%__roles_STORAGE,
        default => \([])
    ));

    $METACLASS->add_attribute(mop::attribute->new( 
        name    => '$attributes', 
        storage => \%__attributes_STORAGE,
        default => \({})
    ));

    $METACLASS->add_attribute(mop::attribute->new( 
        name    => '$methods', 
        storage => \%__methods_STORAGE,
        default => \({})
    ));

    $METACLASS->add_attribute(mop::attribute->new( 
        name    => '$required_methods', 
        storage => \%__required_methods_STORAGE,
        default => \([])
    ));

    # NOTE:
    # we do not include the new method, because
    # we want all meta-extensions to use the one
    # from mop::object.
    # - SL
    $METACLASS->add_method( mop::method->new( name => 'name',       body => \&name       ) );
    $METACLASS->add_method( mop::method->new( name => 'version',    body => \&version    ) );   
    $METACLASS->add_method( mop::method->new( name => 'authority',  body => \&authority  ) );

    $METACLASS->add_method( mop::method->new( name => 'roles',     body => \&roles     ) );
    $METACLASS->add_method( mop::method->new( name => 'add_role',  body => \&add_role  ) );
    $METACLASS->add_method( mop::method->new( name => 'does_role', body => \&does_role ) );

    $METACLASS->add_method( mop::method->new( name => 'attribute_class', body => \&attribute_class ) );
    $METACLASS->add_method( mop::method->new( name => 'attributes',      body => \&attributes      ) );
    $METACLASS->add_method( mop::method->new( name => 'get_attribute',   body => \&get_attribute   ) );
    $METACLASS->add_method( mop::method->new( name => 'add_attribute',   body => \&add_attribute   ) );
    $METACLASS->add_method( mop::method->new( name => 'has_attribute',   body => \&has_attribute   ) );

    $METACLASS->add_method( mop::method->new( name => 'method_class', body => \&method_class ) );
    $METACLASS->add_method( mop::method->new( name => 'methods',      body => \&methods      ) );
    $METACLASS->add_method( mop::method->new( name => 'get_method',   body => \&get_method   ) );
    $METACLASS->add_method( mop::method->new( name => 'add_method',   body => \&add_method   ) );
    $METACLASS->add_method( mop::method->new( name => 'has_method',   body => \&has_method   ) );

    $METACLASS->add_method( mop::method->new( name => 'required_methods',    body => \&required_methods    ) );
    $METACLASS->add_method( mop::method->new( name => 'add_required_method', body => \&add_required_method ) );
    $METACLASS->add_method( mop::method->new( name => 'requires_method',     body => \&requires_method     ) );


    $METACLASS->add_method( mop::method->new( name => 'compose_into', body => \&compose_into ) );

    $METACLASS->add_method( mop::method->new( name => 'FINALIZE', body => \&FINALIZE ) );

    $METACLASS;
}

1;

__END__