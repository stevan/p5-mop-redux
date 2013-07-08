package mop::internals::syntax;

use v5.16;
use warnings;

use base 'Devel::Declare::Context::Simple';

use Hash::Util::FieldHash qw[ fieldhash ];
use Variable::Magic       qw[ wizard ];

use Sub::Name      ();
use Devel::Declare ();
use B::Hooks::EndOfScope;

# keep the local package name around
fieldhash my %CURRENT_CLASS_NAME;

# keep the local type (CLASS or ROLE)
fieldhash my %CURRENT_TYPE;

# Keep a list of attributes currently 
# being compiled in the class because 
# we need to alias them in the method 
# preamble.
fieldhash my %CURRENT_ATTRIBUTE_LIST;

# So this will apply magic to the aliased
# attributes that we put in the method 
# preamble. For `data`, it takes an HASH-ref
# containing the invocant id, the current 
# meta object and the name of the attribute
# we are trying to get/set. Then when our 
# attribute variable is read from or written 
# to it will get/set that data to the 
# underlying fieldhash storage.
our $WIZARD = Variable::Magic::wizard(
    data => sub { 
        my (undef, $config) = @_;
        return $config;
    },
    get  => sub { 
        my ($var, $config) = @_;
        my $attr = $config->{'meta'}->get_attribute( $config->{'name'} );
        ${ $var } = $attr->fetch_data_in_slot_for( $config->{'oid'} );
        ();
    },
    set  => sub { 
        my ($value, $config) = @_;
        my $attr = $config->{'meta'}->get_attribute( $config->{'name'} );
        $attr->store_data_in_slot_for( $config->{'oid'}, ${ $value } ); 
        (); 
    },
);

sub setup_for {
    my $class = shift;
    my $pkg   = shift;
    {
        no strict 'refs';
        *{ $pkg . '::class'     } = sub (&@) {};
        *{ $pkg . '::role'      } = sub (&@) {};
        *{ $pkg . '::has'       } = sub ($@) {};        
        *{ $pkg . '::method'    } = sub (&)  {};
        *{ $pkg . '::submethod' } = sub (&)  {};
    }

    my $context = $class->new;
    Devel::Declare->setup_for(
        $pkg,
        {
            'class'     => { const => sub { $context->class_parser( @_ )     } },
            'role'      => { const => sub { $context->role_parser( @_ )      } },
            'has'       => { const => sub { $context->attribute_parser( @_ ) } },
            'method'    => { const => sub { $context->method_parser( @_ )    } },
            'submethod' => { const => sub { $context->submethod_parser( @_ ) } },
        }
    );
}

sub role_parser {
    my $self = shift;
    $self->init( @_ );
    $self->_namespace_parser('ROLE', 'build_role');
}

sub class_parser {
    my $self = shift;
    $self->init( @_ );
    $self->_namespace_parser('CLASS', 'build_class');
}

sub _namespace_parser {
    my $self = shift;
    my ($type, $builder_method) = @_;

    $self->skip_declarator;

    my $name   = $self->strip_name;
    my $proto  = $self->strip_proto;
    my $caller = $self->get_curstash_name;
    my $pkg    = ($caller eq 'main' ? $name : (join "::" => $caller, $name));

    $CURRENT_TYPE{$self}           = $type;
    $CURRENT_CLASS_NAME{$self}     = $pkg;
    $CURRENT_ATTRIBUTE_LIST{$self} = [];

    # The class preamble is pretty simple, we 
    # evaluate the package into existence, then
    # set it to use our custom MRO, then build
    # our metaclass.
    my $inject = $self->scope_injector_call
        . 'my $d = shift;'
        . 'eval(q[package ' . $pkg .';use strict;use warnings;]);'
        . 'mro::set_mro(q[' . $pkg . '], q[mop]);'
        . '$' . $pkg . '::METACLASS = ' . __PACKAGE__ . '->' . $builder_method . '('
            . 'name => q[' . $pkg . ']' 
            . ($proto ? (', ' . $proto) : '') 
        . ');'
        . '$d->{q[' . $type. ']} = $' . $pkg . '::METACLASS;'
        . 'local ${^' . $type. '} = $d->{q[' . $type. ']};'
        . 'local ${^META} = $d->{q[' . $type. ']};' # mostly for internal use
    ;

    $self->inject_if_block( $inject );

    $self->shadow(sub (&@) {
        my $body = shift;
        my $data = {};

        $body->( $data );

        my $class = $data->{$type};
        $class->FINALIZE;

        return;
    });

    return;
}
sub build_class {
    shift;
    my %metadata = @_;

    my $class_Class = 'mop::class';
    if ( exists $metadata{ 'metaclass' } ) {
        $class_Class = delete $metadata{ 'metaclass' };
    }

    if ( exists $metadata{ 'extends' } ) {
        $metadata{ 'superclass' } = delete $metadata{ 'extends' };
    } else {
        $metadata{ 'superclass' } = 'mop::object';
    }

    if ( exists $metadata{ 'with' } ) {
        $metadata{ 'with' }  = [ $metadata{ 'with' } ] unless ref($metadata{ 'with' }) eq q(ARRAY);
        $metadata{ 'roles' } = [ map { mop::util::find_meta($_) } @{ delete $metadata{ 'with' } } ];
    }

    $class_Class->new(%metadata);    
}

sub build_role {
    shift;
    my %metadata = @_;
    
    if ( exists $metadata{ 'with' } ) {      
        $metadata{ 'with' }  = [ $metadata{ 'with' } ] unless ref($metadata{ 'with' }) eq q(ARRAY);
        $metadata{ 'roles' } = [ map { mop::util::find_meta($_) } @{ delete $metadata{ 'with' } } ];
    }

    mop::role->new(%metadata);
}

sub generic_method_parser {
    my $self     = shift;
    my $callback = shift;

    $self->init( @_ );

    $self->skip_declarator;

    my $name  = $self->strip_name;
    my $proto = $self->strip_proto;

    $self->skipspace;
    if (substr($self->get_linestr, $self->offset, 1) eq ';') {
        $self->shadow(sub {
            ${^META}->add_required_method( $name );
        });
        return;
    }

    my $inject = $self->scope_injector_call;

    $inject .= 'my ($self) = shift(@_);';

    if ($proto) {
        $inject .= 'my (' . $proto . ') = @_;';    
    }

    # create a $class variable, which
    # actually points to the class name
    # and not the metaclass object
    $inject .= 'my $class = $' . $CURRENT_CLASS_NAME{$self} . '::METACLASS->name;';

    # localize ${^SELF} here too 
    $inject .= 'local ${^SELF} = $self;';
    
    # and localize the ${^CLASS} here
    $inject .= 'local ${^' . $CURRENT_TYPE{$self} . '} = $' . $CURRENT_CLASS_NAME{$self} . '::METACLASS;';

    # this is our method preamble, it
    # basically creates a method local
    # variable for each attribute, then 
    # it will cast the magic on it to 
    # make sure that any change in value
    # is stored in the fieldhash storage
    foreach my $attr (@{ $CURRENT_ATTRIBUTE_LIST{$self} }) {
        $inject .= 'my ' . $attr . ';'
                . 'Variable::Magic::cast(' 
                    . $attr . ', '
                    . '$' . __PACKAGE__ . '::WIZARD, '
                    . '{' 
                        . 'meta => $' . $CURRENT_CLASS_NAME{$self} . '::METACLASS,' 
                        . 'oid  => mop::util::get_object_id($self),'
                        . 'name => q[' . $attr . ']'
                    . '}'
                . ');'
                ; 
    }
    
    $self->inject_if_block( $inject );
    $self->shadow($callback->($name));

    return;
}

sub method_parser {
    my $self = shift;
    $self->generic_method_parser(sub {
        my $name = shift;
        return sub (&) {
            my $body = shift;
            ${^META}->add_method(
                ${^META}->method_class->new(
                    name => $name,
                    body => Sub::Name::subname( $name, $body )
                )
            )
        }
    }, @_);
}

sub submethod_parser {
    my $self = shift;
    $self->generic_method_parser(sub {
        my $name = shift;
        return sub (&) {
            my $body = shift;
            ${^META}->add_submethod(
                ${^META}->submethod_class->new(
                    name => $name,
                    body => Sub::Name::subname( $name, $body )
                )
            )
        }
    }, @_);
}

sub attribute_parser {
    my $self = shift;

    $self->init( @_ );

    $self->skip_declarator;
    $self->skipspace;

    my $name;

    my $linestr = $self->get_linestr;
    if ( substr( $linestr, $self->offset, 1 ) eq '$' ) {
        my $length = Devel::Declare::toke_scan_ident( $self->offset );
        $name = substr( $linestr, $self->offset, $length );

        my $full_length = $length;
        my $old_offset  = $self->offset;

        $self->inc_offset( $length );
        $self->skipspace;

        my $proto;
        if ( substr( $linestr, $self->offset, 1 ) eq '(' ) {
            my $length = Devel::Declare::toke_scan_str( $self->offset );
            $proto = Devel::Declare::get_lex_stuff();
            $full_length += $length;
            Devel::Declare::clear_lex_stuff();
            $self->inc_offset( $length );
        }

        $self->skipspace;
        if ( substr( $linestr, $self->offset, 1 ) eq '=' ) {
            $self->inc_offset( 1 );
            $self->skipspace;
            if ( substr( $linestr, $self->offset, 2 ) eq 'do' ) {
                substr( $linestr, $self->offset, 2 ) = 'sub';
            }
        }

        substr( $linestr, $old_offset, $full_length ) = '(' . ( $proto ? $proto : ')');

        $self->set_linestr( $linestr );
        $self->inc_offset( $full_length );
    }

    push @{ $CURRENT_ATTRIBUTE_LIST{$self} } => $name; 

    $self->shadow(sub (@) : lvalue {
        my (%metadata) = @_;
        my $initial_value;
        ${^META}->add_attribute(
            ${^META}->attribute_class->new(
                name    => $name,
                default => \$initial_value,
                %metadata
            )
        );
        $initial_value
    });

    return;
}

sub inject_scope {
    my $class  = shift;
    my $inject = shift || ';';
    on_scope_end {
        my $linestr = Devel::Declare::get_linestr;
        return unless defined $linestr;
        my $offset  = Devel::Declare::get_linestr_offset;
        if ( $inject eq ';' ) {
            substr( $linestr, $offset, 0 ) = $inject;
        }
        else {
            substr( $linestr, $offset - 1, 0 ) = $inject;
        }
        Devel::Declare::set_linestr($linestr);
    };
}

1;

__END__

