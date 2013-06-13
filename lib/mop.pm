package mop;

use strict;
use warnings;

use Package::Stash;

use mop::class;
use mop::method;
use mop::attribute;

use mop::internals::syntax;
use mop::internals::mro;

sub import {
    shift;
    my $pkg = Package::Stash->new( scalar caller );

    my $meta = mop::class->new(
        name       => $pkg->name,
        version    => $pkg->get_symbol('$VERSION'),
        authority  => $pkg->get_symbol('$AUTHORITY'),
        superclass => ($pkg->get_symbol('@ISA') || [])->[0]
    );

    $pkg->add_symbol( '$META' => \$meta );
    $pkg->add_symbol( '&meta' => sub { $meta } );

    mro::set_mro( $pkg->name, 'mop' );
    mop::internals::syntax->setup_for( $pkg->name );
}

1;

__END__