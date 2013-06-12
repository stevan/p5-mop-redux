package mop::internals::mro;

use strict;
use warnings;

use mro;

use MRO::Define;
use Package::Stash;
use Variable::Magic qw[ wizard cast ];

BEGIN {
    MRO::Define::register_mro('mop', sub { ['mop::internals::mro'] })
}

my $method_name;

sub invoke_method {
    my ($caller, @args) = @_;

    my $class = Package::Stash->new( ref($caller) || $caller );

    my $method;
    while ($class) {
        #warn $class->name;
        if ($class->has_symbol('$META')) {
            #warn "in meta";
            # warn "looking up $method_name in meta";
            my $meta = ${ $class->get_symbol('$META') };
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
        
        #warn "looping";
        if ($class->has_symbol('@ISA')) {
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
        ();
    }
);

cast %::mop::internals::mro::, $wiz;

1;

__END__

