package mop::mro;

use v5.16;
use warnings;

use Scalar::Util ();

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

{
    my %ISA_CACHE;

    sub clear_isa_cache {
        my ($class) = ref($_[0]) || $_[0];
        delete $ISA_CACHE{$class};
    }

    sub get_linear_isa {
        my $class = ref($_[0]) || $_[0];

        return $ISA_CACHE{$class} if $ISA_CACHE{$class};

        my @isa;
        my $current = $class;
        while (defined $current) {
            if (my $meta = mop::meta($current)) {
                push @isa, $current;
                $current = $meta->superclass;
            }
            else {
                push @isa, @{ mro::get_linear_isa($current) };
                last;
            }
        }
        return $ISA_CACHE{$class} = \@isa;
    }

    # disable isa caching during global destruction, because things may have
    # started disappearing by that point
    END { %ISA_CACHE = () }
}

package mop::next;

sub method {
    my ($invocant, @args) = @_;
    mop::internals::mro::call_method(
        $invocant,
        ${^CALLER}->[1],
        \@args,
        ${^CALLER}->[2]
    );
}

sub can {
    my ($invocant) = @_;
    my $method = mop::internals::mro::find_method(
        $invocant,
        ${^CALLER}->[1],
        ${^CALLER}->[2]
    );
    return unless $method;
    # NOTE:
    # we need to preserve any events
    # that have been attached to this
    # method.
    # - SL
    return sub { $method->execute( shift, [ @_ ] ) }
        if Scalar::Util::blessed($method) && $method->isa('mop::method');
    return $method;
}

1;
