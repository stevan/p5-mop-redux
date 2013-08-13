package mop::util;

use v5.16;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Package::Stash;
use Hash::Util::FieldHash;
use Scalar::Util qw[ blessed ];

use Sub::Exporter -setup => {
    exports => [qw[
        find_meta
        has_meta
        get_stash_for
        init_attribute_storage
        get_object_id
        fix_metaclass_compatibility
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

sub register_object    { Hash::Util::FieldHash::register( $_[0] ) }
sub get_object_from_id { Hash::Util::FieldHash::id_2obj( $_[0] ) }

sub init_attribute_storage (\%) {
    &Hash::Util::FieldHash::fieldhash( $_[0] )
}

sub install_meta {
    my ($meta) = @_;
    my $stash = mop::util::get_stash_for($meta->name);
    $stash->add_symbol('$METACLASS', \$meta);
    $stash->add_symbol('$VERSION', \$meta->version);
    mro::set_mro($meta->name, 'mop');
}

sub uninstall_meta {
    my ($meta) = @_;
    my $stash = mop::util::get_stash_for($meta->name);
    $stash->remove_symbol('$METACLASS');
    $stash->remove_symbol('$VERSION');
    mro::set_mro($meta->name, 'dfs');
}

sub fix_metaclass_compatibility {
    my ($meta, $super) = @_;

    my $meta_name  = blessed($meta);
    return $meta_name if !defined $super; # non-mop inheritance

    my $super_name = blessed($super);

    # immutability is on a per-class basis, it shouldn't be inherited.
    # otherwise, subclasses of closed classes won't be able to do things
    # like add attributes or methods to themselves
    $meta_name = mop::get_meta($meta_name)->superclass
        if $meta->is_closed;
    $super_name = mop::get_meta($super_name)->superclass
        if $super->is_closed;

    return $meta_name  if $meta->isa($super_name);
    return $super_name if $super->isa($meta_name);
    # XXX we should be able to fix up simple role incompatibilities too

    die "Can't fix metaclass compatibility between "
      . $meta->name . " (" . $meta_name . ") and "
      . $super->name . " (" . $super_name . ")";
}

package mop::mro;

use strict;
use warnings;

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
            if (my $meta = mop::util::find_meta($current)) {
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

use strict;
use warnings;

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

__END__

=pod

=head1 NAME

mop::util - collection of utilities for the mop

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

