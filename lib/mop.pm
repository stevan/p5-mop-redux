package mop;

use strict;
use warnings;

use mop::class;
use mop::method;
use mop::attribute;

use mop::internals::package;
use mop::internals::mro;

sub import {
    shift;
    my $pkg = mop::internals::package->new( scalar caller );

    mro::set_mro( $pkg->name, 'mop' );

    my $meta = mop::class->new(
        name       => $pkg->name,
        version    => $pkg->get_symbol('$VERSION'),
        authority  => $pkg->get_symbol('$AUTHORITY'),
        superclass => ($pkg->get_symbol('@ISA') || [])->[0]
    );

    $pkg->add_symbol( '$META' => \$meta );
    $pkg->add_symbol( '&meta' => sub { $meta } );
}

1;

__END__