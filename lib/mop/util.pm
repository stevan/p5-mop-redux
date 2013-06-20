package mop::util;

use strict;
use warnings;

use Package::Stash;

use Sub::Exporter -setup => {
    exports => [qw[
        find_meta
        get_mro_for
        WALKCLASS
    ]]
};

sub find_meta {
    ${ Package::Stash->new(shift)->get_symbol('$METACLASS') }
}

sub get_mro_for {
    my $class = shift;
    if (my $meta = find_meta($class)) {
        if (my $super = $meta->superclass) {
            return [ $class, @{ get_mro_for($super) || [] } ];
        }
    } else {
        return mro::get_linear_isa($class);
    }
}

sub WALKCLASS {
    my $c = shift;
    my $f = shift;
    map { $f->($_) } get_mro_for($c); 
}

1;

__END__