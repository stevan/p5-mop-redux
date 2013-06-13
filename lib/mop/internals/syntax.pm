package mop::internals::syntax;

use strict;
use warnings;

use base 'Devel::Declare::Context::Simple';

use Sub::Name      ();
use Devel::Declare ();
use B::Hooks::EndOfScope;

sub setup_for {
    my $class = shift;
    my $pkg   = shift;
    {
        no strict 'refs';
        *{ $pkg . '::class'     } = sub (&@) {};        
        *{ $pkg . '::method'    } = sub (&)  {};
        *{ $pkg . '::submethod' } = sub (&)  {};
    }

    my $context = $class->new;
    Devel::Declare->setup_for(
        $pkg,
        {
            'class'     => { const => sub { $context->class_parser( @_ )     } },
            'method'    => { const => sub { $context->method_parser( @_ )    } },
            'submethod' => { const => sub { $context->submethod_parser( @_ ) } },
        }
    );
}

sub class_parser {
    my $self = shift;

    $self->init( @_ );

    $self->skip_declarator;

    my $name   = $self->strip_name;
    my $proto  = $self->strip_proto;
    my $caller = $self->get_curstash_name;
    my $pkg    = ($caller eq 'main' ? $name : (join "::" => $caller, $name));

    my $inject = $self->scope_injector_call
               . 'my $d = shift;'
               . 'eval("package ' . $pkg . '; use strict; use warnings; our \$META; our \@ISA");'
               . 'mro::set_mro("' . $pkg . '", "mop");'
               . '$d->{"class"} = ' . __PACKAGE__ . '->build_class(' 
                   . 'name => "' . $pkg . '"' 
                   . ($proto ? (', ' . $proto) : '') 
               . ');'
               . 'local $::CLASS = $d->{"class"};'
               . '$' . $pkg . '::META = $d->{"class"};'
               ;
    $self->inject_if_block( $inject );

    $self->shadow(sub (&@) {
        my $body = shift;
        my $data = {};

        $body->( $data );

        #use Data::Dumper 'Dumper'; warn Dumper( $data->{'class'} ); 

        return;
    });

    return;
}

sub build_class {
    shift;
    my %metadata = @_;

    if ( exists $metadata{ 'extends' } ) {
        $metadata{ 'superclass' } = delete $metadata{ 'extends' };
    }

    mop::class->new(%metadata);    
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

