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

    my $class = Package::Stash->new( ref($caller) || $caller );

    # *sigh* Devel::Declare does this
    if ( $method_name eq 'can' && ($args[0] eq 'method' || $args[0] eq 'class') ) {
        return $class->name->UNIVERSAL::can( @args );
    }

    my $has_looped = 0;
    my $method;
    while ($class) {
        #warn $class->name;
        if ($class->has_symbol('$METACLASS')) {
            #warn "in meta";
            #warn "looking up $method_name in meta";
            my $meta = ${ $class->get_symbol('$METACLASS') };
            if (not($has_looped) && $meta->has_submethod( $method_name )) {
                $method = $meta->get_submethod( $method_name )->body;
                last;
            }
            if ($meta->has_method( $method_name )) {
                $method = $meta->get_method( $method_name )->body;
                last;
            }
        }
        elsif ($class->has_symbol('&' . $method_name)) {
            #warn "looking up old fashioned symbol";
            $method = $class->get_symbol('&' . $method_name);
            last;
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
    
    die "Could not find $method_name in " . $caller unless defined $method;
    
    $method->($caller, @args);
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

1;

__END__

