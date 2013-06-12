package mop;

use strict;
use warnings;

use Package::Stash;

use mop::internals::mro;
use mop::internals::class;
use mop::internals::method;
use mop::internals::attribute;

sub import {
    shift;
    my $pkg = Package::Stash->new( scalar caller );

    mro::set_mro( $pkg->name, 'mop' );

    my $meta = mop::internals::class->new(
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