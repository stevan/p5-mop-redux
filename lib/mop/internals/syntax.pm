package mop::internals::syntax;

use strict;
use warnings;

use base 'Devel::Declare::Context::Simple';

use Sub::Name             ();
use Devel::Declare        ();
use Hash::Util::FieldHash ();
use Variable::Magic       ();
use B::Hooks::EndOfScope;

sub setup_for {
    my $class = shift;
    my $pkg   = shift;
    {
        no strict 'refs';
        *{ $pkg . '::class'     } = sub (&@) {};
        *{ $pkg . '::has'       } = sub ($@) {};        
        *{ $pkg . '::method'    } = sub (&)  {};
        *{ $pkg . '::submethod' } = sub (&)  {};
    }

    my $context = $class->new;
    Devel::Declare->setup_for(
        $pkg,
        {
            'class'     => { const => sub { $context->class_parser( @_ )     } },
            'has'       => { const => sub { $context->attribute_parser( @_ ) } },
            'method'    => { const => sub { $context->method_parser( @_ )    } },
            'submethod' => { const => sub { $context->submethod_parser( @_ ) } },
        }
    );
}

my $CLASS;
my @ATTRIBUTES;

sub class_parser {
    my $self = shift;

    $self->init( @_ );

    $self->skip_declarator;

    my $name   = $self->strip_name;
    my $proto  = $self->strip_proto;
    my $caller = $self->get_curstash_name;
    my $pkg    = ($caller eq 'main' ? $name : (join "::" => $caller, $name));

    $CLASS = $pkg;

    my (@PLAN, @EVAL);
    push @EVAL => 'package ' . $pkg .';';
    push @EVAL => 'use strict;';
    push @EVAL => 'use warnings;';

    push @PLAN => 'eval(q[' . (join '' => @EVAL) . ']);';
    push @PLAN => 'mro::set_mro(q[' . $pkg . '], q[mop]);';
    push @PLAN => '$' . $pkg . '::__WIZARD__ = Variable::Magic::wizard('
        . 'data => sub { $_[1] },'
        . 'set  => sub { $_[1]->[0]->{ $_[1]->[1] } = $_[0] },'
    . ');';
    push @PLAN => '$' . $pkg . '::__META__ = ' . __PACKAGE__ . '->build_class('
        . 'name => q[' . $pkg . ']' 
        . ($proto ? (', ' . $proto) : '') 
    . ');';
    push @PLAN => 'local $::CLASS = $' . $pkg . '::__META__;';

    my $inject = $self->scope_injector_call . join "" => @PLAN;

    $self->inject_if_block( $inject );

    $self->shadow(sub (&@) {
        my $body = shift;

        $body->();

        return;
    });

    #$CLASS      = undef;
    @ATTRIBUTES = ();

    return;
}

sub build_class {
    shift;
    my %metadata = @_;

    if ( exists $metadata{ 'extends' } ) {
        $metadata{ 'superclass' } = delete $metadata{ 'extends' };
    } else {
        $metadata{ 'superclass' } = 'mop::object';
    }

    my $class = mop::class->new(%metadata);    

    $class->add_submethod(
        mop::method->new(
            name => 'meta',
            body => sub { $class }
        )
    );

    $class;
}

sub generic_method_parser {
    my $self     = shift;
    my $callback = shift;

    $self->init( @_ );

    $self->skip_declarator;

    my $name   = $self->strip_name;
    my $proto  = $self->strip_proto;
    my $inject = $self->scope_injector_call;
    if ($proto) {
        $inject .= 'my ($self, ' . $proto . ') = @_;';    
    }
    else {
        $inject .= 'my ($self) = @_;';
    }

    foreach my $attr (@ATTRIBUTES) {
        my $key_name = substr( $attr, 1, length $attr );
        $inject .= 'my ' . $attr . ' = ${ ' . $attr . '{$self} || \(undef) };';
        $inject .= 'Variable::Magic::cast(' . $attr . ', $' . $CLASS . '::__WIZARD__, [ \%' . $key_name . ', $self ]);'; 
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
            $::CLASS->add_method(
                mop::method->new(
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
            $::CLASS->add_submethod(
                mop::method->new(
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

        substr( $linestr, $old_offset, $full_length ) = '(q[' . $name . '])' . ( $proto ? (', (' . $proto) : '');

        my $key_name  = substr( $name, 1, length $name );
        my $fieldhash = 'Hash::Util::FieldHash::fieldhash(my %' . $key_name . ');';
        $full_length += length($fieldhash);

        substr( $linestr, length($linestr) - 1, $full_length ) = $fieldhash;

        $self->set_linestr( $linestr );
        $self->inc_offset( $full_length );
    }

    push @ATTRIBUTES => $name; 

    $self->shadow(sub ($@) : lvalue {
        shift;
        my %metadata = @_;
        my $initial_value;
        $::CLASS->add_attribute(
            mop::attribute->new(
                name    => $name,
                default => sub { $initial_value },
            )
        );
        $initial_value
    });

    return;
}

sub scope_injector_call {
  my $self = shift;
  my $inject = shift || '';
  return ' BEGIN { ' . ref($self) . "->inject_scope('${inject}') }; ";
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

