package mop::internals::mro;

use strict;
use warnings;

use mro;

use Package::Stash;
use MRO::Define;
use Variable::Magic qw[ wizard cast ];
use Carp            qw[ confess ];

BEGIN {
    MRO::Define::register_mro('mop', sub { [ 'UNIVERSAL', 'mop::internals::mro' ] })
}

my $method_name;

sub invoke_method {
    my ($caller, @args) = @_;
    call_method($caller, $method_name, \@args);
}

sub call_method {
    my ($caller, $meth_name, $args, %opts) = @_;

    my $class = Package::Stash->new( ref($caller) || $caller );

    # *sigh* Devel::Declare does this
    if ( $meth_name eq 'can' && ($args->[0] eq 'method' || $args->[0] eq 'class') ) {
        return $class->name->UNIVERSAL::can( @$args );
    }

    my $has_looped = 0;
    my $method;
    while ($class) {
        #warn $class->name;

        if (!$opts{'super'}) {
            if ($class->has_symbol('$METACLASS')) {
                #warn "in meta";
                #warn "looking up $meth_name in meta";
                my $meta = ${ $class->get_symbol('$METACLASS') };
                if (not($has_looped) && $meta->has_submethod( $meth_name )) {
                    $method = $meta->get_submethod( $meth_name )->body;
                    last;
                }
                if ($meta->has_method( $meth_name )) {
                    $method = $meta->get_method( $meth_name )->body;
                    last;
                }
            }
            elsif ($class->has_symbol('&' . $meth_name)) {
                #warn "looking up old fashioned symbol";
                $method = $class->get_symbol('&' . $meth_name);
                last;
            }
        }
        else {
            #warn "calling super method $meth_name ...";
            $opts{'super'} = 0;
        }

        $has_looped++;
        #warn "looping";
        if ($class->has_symbol('$METACLASS')) {
            my $meta = ${ $class->get_symbol('$METACLASS') };
            if (my $super = $meta->superclass) {
                $class = Package::Stash->new( $super )
            }
            else {
                $class = undef;
            }
        }
        elsif ($class->has_symbol('@ISA') && scalar @{ $class->get_symbol('@ISA') }) {
            $class = Package::Stash->new( $class->get_symbol('@ISA')->[0] )
        }
        else {
            $class = undef;
        }
    }
    
    die "Could not find $meth_name in " . $caller unless defined $method;
    
    $method->($caller, @$args);
}

my $wiz = wizard(
    data  => sub { \$method_name },
    fetch => sub {
        return if $_[2] =~ /^\(/      # no overloaded methods
               || $_[2] eq 'DESTROY'  # no DESTROY (for now)
               || $_[2] eq 'AUTOLOAD' # no AUTOLOAD (never!!)
               || $_[2] eq 'import'   # classes don't import
               || $_[2] eq 'export';  # and they certainly don't export
        #warn join ", " => @_;
        ${ $_[1] } = $_[2];
        $_[2] = 'invoke_method';
        mro::method_changed_in('UNIVERSAL');
        ();
    }
);

cast %::mop::internals::mro::, $wiz;

package mop::next;

sub method {
    my ($invocant, @args) = @_;
    my $method_name = (split '::' => (caller(1))[3])[-1];
    mop::internals::mro::call_method($invocant, $method_name, \@args, super => 1);
}

1;

__END__

