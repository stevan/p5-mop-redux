package mop::internals::mro;

use v5.16;
use warnings;

use mop::util qw[ find_meta ];

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

{
    my %METHOD_CACHE;

    sub clear_method_cache_for {
        my ($invocant) = @_;
        delete $METHOD_CACHE{method_cache_for($invocant)};
    }

    sub method_cache_lookup {
        my ($invocant, $method_name, $super_of) = @_;
        my $pkg = method_cache_for($invocant);
        my $super = $super_of ? $super_of->name : '';
        return $METHOD_CACHE{$pkg}{$method_name}{$super};
    }

    sub add_to_method_cache {
        my ($invocant, $method_name, $super_of, $method) = @_;
        my $pkg = method_cache_for($invocant);
        my $super = $super_of ? $super_of->name : '';
        $METHOD_CACHE{$pkg}{$method_name}{$super} = $method;
    }

    sub method_cache_for {
        my ($invocant) = @_;
        return blessed($invocant) || $invocant;
    }

    # disable method caching during global destruction, because things may have
    # started disappearing by that point
    END { %METHOD_CACHE = () }
}

sub find_method {
    my ($invocant, $method_name, $super_of) = @_;
    if (my $method = method_cache_lookup($invocant, $method_name, $super_of)) {
        return $method;
    }
    return add_to_method_cache(
        $invocant, $method_name, $super_of,
        _find_method($invocant, $method_name, $super_of)
    );
}

sub _find_method {
    my ($invocant, $method_name, $super_of) = @_;

    my @mro = @{ mop::mro::get_linear_isa( $invocant ) };

    # NOTE:
    # this is ugly, needs work
    # - SL
    if ( defined $super_of ) {
        while ( $mro[0] && $mro[0] ne $super_of->name ) {
            shift( @mro );
        }
        shift( @mro );
    }

    foreach my $class ( @mro ) {
        if (my $meta = find_meta($class)) {
            return $meta->get_method( $method_name )
                if $meta->has_method( $method_name );
        } else {
            my $stash = mop::internals::util::get_stash_for( $class );
            return $stash->get_symbol( '&' . $method_name )
                if $stash->has_symbol( '&' . $method_name );
        }
    }

    if (my $universally = UNIVERSAL->can($method_name)) {
        if (my $method = find_meta('mop::object')->get_method($method_name)) {
            # we're doing method lookup on a mop class which doesn't inherit
            # from mop::object (otherwise this would have been found above). we
            # need to use the mop::object version of the appropriate UNIVERSAL
            # methods, because the methods in UNIVERSAL won't necessarily do
            # the right thing for mop objects.
            return $method;
        }
        else {
            # a method which was added to UNIVERSAL manually, or a method whose
            # implementation in UNIVERSAL also works for mop objects
            return $universally;
        }
    }

    return;
}

sub find_submethod {
    my ($invocant, $method_name) = @_;

    if (my $meta = find_meta($invocant)) {
        return $meta->get_submethod( $method_name );
    }

    return;
}

sub call_method {
    my ($invocant, $method_name, $args, $super_of) = @_;

    # XXX
    # for some reason, we are getting a lot
    # of "method not found" type errors in
    # 5.18 during local scope destruction
    # and there doesn't seem to be any
    # sensible way to fix this. Hence, this
    # horrid fucking kludge.
    # - SL
    local $SIG{'__WARN__'} = sub {
        warn $_[0] unless $_[0] =~ /\(in cleanup\)/
    };

    my $method = find_submethod( $invocant, $method_name );
    $method    = find_method( $invocant, $method_name, $super_of )
        unless defined $method;

    die "Could not find $method_name in " . overload::StrVal($invocant)
        unless defined $method;

    if ( blessed $method && $method->isa('mop::method') ) {
        return $method->execute( $invocant, $args );
    } elsif ( ref $method eq 'CODE' ) {
        return $method->($invocant, @$args);
    } else {
        die "Unrecognized method type: $method";
    }
}

# Here is where things get a little ugly,
# we need to wrap the stash in magic so
# that we can capture calls to it
{
    my $method_called;
    my $is_fetched = 0;

    sub invoke_method {
        my ($caller, @args) = @_;

        # so perl keeps an additional cache of DESTROY methods, beyond the
        # normal method caching. this cache isn't affected by the mro stuff.
        # DESTROY is the only method (so far) cached in this way, so we can
        # just assume that if the method wasn't fetched, it was being pulled
        # from the DESTROY cache.
        if (!$is_fetched) {
            $method_called = 'DESTROY';
        }
        $is_fetched = 0;

        call_method($caller, $method_called, \@args);
    }

    my $wiz = wizard(
        data  => sub { [ \$method_called, \$is_fetched ] },
        fetch => sub {
            return if $_[2] =~ /^\(/      # no overloaded methods
                   || $_[2] eq 'AUTOLOAD' # no AUTOLOAD (never!!)
                   || $_[2] eq 'import'   # classes don't import
                   || $_[2] eq 'unimport';  # and they certainly don't export
            return if $_[2] eq 'DESTROY' && in_global_destruction;

            ${ $_[1]->[1] } = 1;
            ${ $_[1]->[0] } = $_[2];
            $_[2] = 'invoke_method';
            mro::method_changed_in('UNIVERSAL');

            ();
        }
    );

    cast %::mop::internals::mro::, $wiz;
}

1;

__END__

=pod

=head1 NAME

mop::internal::mro

=head1 DESCRIPTION

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 AUTHOR

Stevan Little <stevan@iinteractive.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Infinity Interactive.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut






