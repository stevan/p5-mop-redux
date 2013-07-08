package mop::util;

use v5.16;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Package::Stash;
use Hash::Util::FieldHash;

use Sub::Exporter -setup => {
    exports => [qw[
        find_meta
        has_meta
        get_stash_for
        init_attribute_storage
        get_object_id
    ]]
};

sub find_meta { ${ get_stash_for( shift )->get_symbol('$METACLASS') || \undef } }
sub has_meta  {    get_stash_for( shift )->has_symbol('$METACLASS')  }

sub get_stash_for { 
    state %STASHES;
    my $class = ref($_[0]) || $_[0];
    $STASHES{ $class } //= Package::Stash->new( $class ) 
}

sub get_object_id { Hash::Util::FieldHash::id( $_[0] ) }

sub init_attribute_storage (\%) {
    &Hash::Util::FieldHash::fieldhash( $_[0] )
}

package mop::mro;

use strict;
use warnings;

sub get_linear_isa {
    my $class = shift;
    if (my $meta = mop::util::find_meta($class)) {
        # NOTE:
        # Roles have no ISA, but this question 
        # is asked by the dispatcher so we need
        # to be able to handle it.
        # - SL
        return [ $meta->name ] if $meta->isa('mop::role');
        if (my $super = $meta->superclass) {
            return [ $meta->name, @{ get_linear_isa($super) || [] } ];
        } else {
            return [ $meta->name ];
        }
    } else {
        return mro::get_linear_isa($class);
    }
}

package mop::next;

use strict;
use warnings;

sub method {
    my ($invocant, @args) = @_;
    mop::internals::mro::call_method(
        $invocant, 
        ${^CALLER}->[1], 
        \@args, 
        super_of => ${^CALLER}->[2]
    );
}

1;

__END__