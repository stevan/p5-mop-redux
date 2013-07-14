package mop::internals::syntax;

use v5.16;
use warnings;

use base 'Devel::Declare::Context::Simple';

use Hash::Util::FieldHash qw[ fieldhash ];
use Variable::Magic       qw[ wizard ];

use Sub::Name       ();
use Devel::Declare  ();
use Module::Runtime ();
use B::Hooks::EndOfScope;

# keep the local package name around
fieldhash my %CURRENT_CLASS_NAME;

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

    $self->skipspace;
    my $linestr = $self->get_linestr;

    my @classes_to_load;

    if (my $class_name = $self->parse_modifier_with_single_value(\$linestr, 'extends')) {
        $proto = ($proto ? $proto . ', ' : '') . ('extends => q[' . $class_name . ']');    
        push @classes_to_load => $class_name;
    }

    if (my @roles = $self->parse_modifier_with_multiple_values(\$linestr, 'with')) {
        $proto = ($proto ? $proto . ', ' : '') . ('with => [qw[' . (join " " => @roles) . ']]');
        push @classes_to_load => @roles;
    }

    if (my $class_name = $self->parse_modifier_with_single_value(\$linestr, 'metaclass')) {
        $proto = ($proto ? $proto . ', ' : '') . ('metaclass => q[' . $class_name . ']');    
        push @classes_to_load => $class_name;
    }  

    my @traits = $self->trait_collector(\$linestr, '$' . $pkg . '::METACLASS');

    $CURRENT_CLASS_NAME{$self}     = $pkg;
    $CURRENT_ATTRIBUTE_LIST{$self} = [];

    # The class preamble is pretty simple, we 
    # evaluate the package into existence, then
    # set it to use our custom MRO, then build
    # our metaclass.
    my $inject = $self->scope_injector_call
        . (join '' => map  { 
                '{'
                    . 'local $@;'
                    . 'eval(q[use ' . $_ . ']);'
                    . 'Module::Runtime::use_package_optimistically(q[' . $_ . ']) if $@;'
                    . 
                '}' 
            } grep { !mop::util::has_meta( $_ ) } @classes_to_load)
        . 'eval(q[package ' . $pkg .';]);'
        . 'mro::set_mro(q[' . $pkg . '], q[mop]);'
        . '$' . $pkg . '::METACLASS = ' . __PACKAGE__ . '->' . $builder_method . '('
            . 'name => q[' . $pkg . ']' 
            . ($proto ? (', ' . $proto) : '') 
        . ');'
        . 'local ${^' . $type. '} = $' . $pkg . '::METACLASS;'
        . 'local ${^META} = $' . $pkg . '::METACLASS;' # mostly for internal use
        . 'BEGIN { mop::internals::syntax->inject_scope(q[' 
            . (join ';' => @traits) 
            . ';$' . $pkg . '::METACLASS->FINALIZE;'
        . ']) }'
    ;

    $self->inject_if_block( $inject );

    $self->shadow(sub (&@) {
        my $body = shift;

        $body->();

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

sub parse_modifier_with_single_value {
    my ($self, $linestr, $modifier) = @_;
    
    my $modifier_length = length $modifier;

    if ( substr( $$linestr, $self->offset, $modifier_length ) eq $modifier ) {
        my $orig_offset = $self->offset;

        $self->inc_offset( $modifier_length );
        $self->skipspace;

        my $length = Devel::Declare::toke_scan_ident( $self->offset );
        my $value  = substr( $$linestr, $self->offset, $length );

        $self->inc_offset( $length );

        my $full_length = $self->offset - $orig_offset;

        substr( $$linestr, $orig_offset, $full_length ) = '';

        $self->set_linestr( $$linestr );
        $self->{Offset} = $orig_offset;
        $self->skipspace;

        return $value;
    }
}

sub parse_modifier_with_multiple_values {
    my ($self, $linestr, $modifier) = @_;
    
    my $modifier_length = length $modifier;

    if ( substr( $$linestr, $self->offset, $modifier_length ) eq $modifier ) {
        my $orig_offset = $self->offset;

        $self->inc_offset( $modifier_length );
        $self->skipspace;

        my @values;

        my $length = Devel::Declare::toke_scan_ident( $self->offset );
        push @values => substr( $$linestr, $self->offset, $length );
        $self->inc_offset( $length );

        while (substr( $$linestr, $self->offset, 1 ) eq ',') {
            $self->inc_offset( 1 );
            $self->skipspace;
            my $length = Devel::Declare::toke_scan_ident( $self->offset );
            push @values => substr( $$linestr, $self->offset, $length );
            $self->inc_offset( $length );            
        }

        my $full_length = $self->offset - $orig_offset;

        substr( $$linestr, $orig_offset, $full_length ) = '';

        $self->set_linestr( $$linestr );
        $self->{Offset} = $orig_offset;
        $self->skipspace;

        return @values;
    }  

    return ();  
}

sub trait_parser {
    my ($self, $linestr, $meta_object, $type, $name) = @_;

    my $length = Devel::Declare::toke_scan_ident( $self->offset );
    my $trait  = substr( $$linestr, $self->offset, $length );
    $self->inc_offset( $length );

    if ( substr( $$linestr, $self->offset, 1 ) eq '(' ) {
        my $length = Devel::Declare::toke_scan_str( $self->offset );
        my $proto  = Devel::Declare::get_lex_stuff();
        Devel::Declare::clear_lex_stuff();
        $self->inc_offset( $length );
        $trait .= '(' . $meta_object . ', q[' . $type . '], [ q[' . $name . '], ' . $proto . '])';
    } else {
        if ($type && $name) {
            $trait .= '(' . $meta_object . ', q[' . $type . '], [ q[' . $name . '] ])';
        } else {
            $trait .= '(' . $meta_object . ')';
        }
    }

    return $trait;
}

sub trait_collector {
    my ($self, $linestr, $meta_object, $type, $name) = @_;

    if ( substr( $$linestr, $self->offset, 2 ) eq 'is' ) {
        my @traits;

        my $orig_offset = $self->offset;

        $self->inc_offset( 2 );
        $self->skipspace;

        push @traits => $self->trait_parser($linestr, $meta_object, $type, $name);

        while (substr( $$linestr, $self->offset, 1 ) eq ',') {
            $self->inc_offset( 1 );
            push @traits => $self->trait_parser($linestr, $meta_object, $type, $name);
        }

        my $full_length = $self->offset - $orig_offset;

        substr( $$linestr, $orig_offset, $full_length ) = '';

        $self->set_linestr( $$linestr );
        $self->{Offset} = $orig_offset;
        $self->skipspace;

        return @traits;
    }  
}

sub generic_method_parser {
    my $self     = shift;
    my $callback = shift;

    $self->init( @_ );

    $self->skip_declarator;

    my $name    = $self->strip_name;
    my $proto   = $self->strip_proto;
    my $linestr = $self->get_linestr;

    $self->skipspace;

    my @traits = $self->trait_collector(
        \$linestr, 
        '$' . $CURRENT_CLASS_NAME{$self} . '::METACLASS', 'method', $name
    );

    if (@traits) {
        $self->inject_scope(';' . (join ";" => @traits) . ';')
    }    

    $self->skipspace;
    if (substr($linestr, $self->offset, 1) eq ';') {
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

    $inject .= 'local ${^CALLER} = [ $self, q[' . $name . '], $' . $CURRENT_CLASS_NAME{$self} . '::METACLASS ];';

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

        my @traits = $self->trait_collector(
            \$linestr, 
            '$' . $CURRENT_CLASS_NAME{$self} . '::METACLASS', 'attribute', $name
        );

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

        if (@traits) {
            $self->inject_scope(';' . (join ";" => @traits) . ';')
        }
    }

    push @{ $CURRENT_ATTRIBUTE_LIST{$self} } => $name; 

    $self->shadow(sub (@) : lvalue {
        my (%metadata) = @_;
        my $initial_value;

        my $attribute_Class = ${^META}->attribute_class;
        if ( exists $metadata{ 'metaclass' } ) {
            $attribute_Class = delete $metadata{ 'metaclass' };
        }

        ${^META}->add_attribute(
            $attribute_Class->new(
                name    => $name,
                default => \$initial_value,
                %metadata
            )
        );
        $initial_value
    });

    return;
}

1;

__END__

=pod

=head1 NAME

mop::internal::syntax

=head1 DESCRIPTION

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 AUTHOR

Stevan Little <stevan@iinteractive.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Infinity Interactive.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut







