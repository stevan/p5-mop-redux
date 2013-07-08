package mop::internals::mro;

use v5.16;
use warnings;

use mop::util qw[ 
    has_meta 
    find_meta 
    get_stash_for 
];

use Devel::GlobalDestruction;
use MRO::Define;
use Scalar::Util    qw[ blessed ];
use Variable::Magic qw[ wizard cast ];

BEGIN {
    MRO::Define::register_mro(
        'mop', 
        sub { [ 'mop::internals::mro' ] }
    )
}

sub find_method {
    my ($invocant, $method_name, %opts) = @_;

    my @mro = @{ mop::mro::get_linear_isa( $invocant ) };

    # NOTE: 
    # this is ugly, needs work 
    # - SL
    if ( exists $opts{'super_of'} ) {
        #warn "got super-of";
        #warn "MRO: " . $mro[0];
        #warn "SUPEROF: " . $opts{'super_of'}->name;
        if ( $mro[0] && $mro[0] eq $opts{'super_of'}->name ) {
            #warn "got match, shifting";
            shift( @mro );
        } else {
            #warn "no match, looking"; 
            while ( $mro[0] && $mro[0] ne $opts{'super_of'}->name ) {
                #warn "no match, shifting until we find it";
                shift( @mro );
            }    
            #warn "got it, shifting";
            shift( @mro );
        }

    }

    foreach my $class ( @mro ) {
        if ( has_meta( $class ) ) {
            my $meta = find_meta( $class );
            return $meta->get_method( $method_name )
                if $meta->has_method( $method_name );
        } else {
            my $stash = get_stash_for( $class );
            return $stash->get_symbol( '&' . $method_name )
                if $stash->has_symbol( '&' . $method_name );
        }
    }

    # this is just because 
    # UNIVERSAL never shows
    # up in the mro and so
    # we have to look for 
    # these explicitly
    if ($method_name eq 'can' || $method_name eq 'isa') {
        return find_meta('mop::object')->get_method( $method_name );
    }

    # UNIVERSAL has other
    # built-in methods such
    # as DOES, VERSION and
    # potentially others
    if (my $universally = 'UNIVERSAL'->can($method_name)) {
        return $universally;
    }

    return;
}

sub find_submethod {
    my ($invocant, $method_name, %opts) = @_;

    if ( has_meta( $invocant ) ) {
        my $meta = find_meta( $invocant );
        # NOTE:
        # we need to bail on this if 
        # the metaclass is a role
        # - SL
        return if $meta->isa('mop::role');
        return $meta->get_submethod( $method_name )
            if $meta->has_submethod( $method_name );
    }

    return;
}

sub call_method {
    my ($invocant, $method_name, $args, %opts) = @_;

    my $class = get_stash_for( $invocant );

    # *sigh* Devel::Declare does this and we need to ignore it
    if ( $method_name eq 'can' && ($args->[0] eq 'method' || $args->[0] eq 'class') ) {
        return $class->name->UNIVERSAL::can( @$args );
    }

    my $method = find_submethod( $invocant, $method_name, %opts );
    $method    = find_method( $invocant, $method_name, %opts )
        unless defined $method;

    # XXX 
    # this is f-ing stupid, but under `make test`
    # in_global_destruction is not working right
    # and I am getting errors in the test:
    #
    # > t/050-non-mop-integration/001-inherit-from-non-mop.t
    # 
    # This should be removed ASAP.
    # - SL
    return if $method_name eq 'DESTROY' && not defined $method;

    die "Could not find $method_name in " . $invocant
        unless defined $method;
    
    # need to localize these two 
    # globals here so that they 
    # will be available to methods
    # added with "add_method" as 
    # well as 
    local ${^SELF}  = $invocant;
    local ${^CLASS} = find_meta($invocant) if has_meta($invocant);

    if ( ref $method eq 'CODE' ) {
        return $method->($invocant, @$args);
    } elsif ( blessed $method && $method->isa('mop::method') ) {
        return $method->execute( $invocant, $args );
    } else {
        die "Unrecognized method type: $method";
    }
}

# Here is where things get a little ugly, 
# we need to wrap the stash in magic so 
# that we can capture calls to it
{
    my $method_called;

    sub invoke_method {
        my ($caller, @args) = @_;
        call_method($caller, $method_called, \@args);
    }

    my $wiz = wizard(
        data  => sub { \$method_called },
        fetch => sub {
            return if $_[2] =~ /^\(/      # no overloaded methods
                   || $_[2] eq 'AUTOLOAD' # no AUTOLOAD (never!!)
                   || $_[2] eq 'import'   # classes don't import
                   || $_[2] eq 'unimport';  # and they certainly don't export
            return if $_[2] eq 'DESTROY' && in_global_destruction;
            #warn join ", " => @_;
            ${ $_[1] } = $_[2];
            $_[2] = 'invoke_method';
            mro::method_changed_in('UNIVERSAL');
            ();
        }
    );

    cast %::mop::internals::mro::, $wiz;
}

1;

__END__

