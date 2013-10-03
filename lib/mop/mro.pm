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

1;
