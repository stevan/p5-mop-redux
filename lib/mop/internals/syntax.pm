package mop::internals::syntax;

use strict;
use warnings;

use base 'Devel::Declare::Context::Simple';

use Package::Stash;
use Sub::Name      ();
use Devel::Declare ();
use B::Hooks::EndOfScope;

sub setup_for {
    my $class = shift;
    my $pkg   = shift;
    {
        no strict 'refs';
        *{ $pkg . '::method' } = sub (&)  {};
    }

    my $context = $class->new;
    Devel::Declare->setup_for(
        $pkg,
        {
            'method' => { 
                const => sub { 
                    $context->method_parser( $pkg, @_ ) 
                } 
            },
        }
    );
}

sub method_parser {
    my $self = shift;

    my $pkg  = Package::Stash->new( shift );
    my $meta = ${ $pkg->get_symbol('$META') };

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
    $self->shadow( sub (&) {
        my $body = shift;
        $meta->add_method(
            mop::method->new(
                name => $name,
                body => Sub::Name::subname( $name, $body )
            )
        )
    } );

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

