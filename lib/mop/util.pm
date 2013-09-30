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
        find_or_create_meta
        get_stash_for
        init_attribute_storage
        get_object_id
        apply_all_roles
        fix_metaclass_compatibility
        rebless
        apply_metaclass
        dump_object
    ]]
};

sub find_meta { ${ get_stash_for( shift )->get_symbol('$METACLASS') || \undef } }
sub has_meta  {    get_stash_for( shift )->has_symbol('$METACLASS')  }

# this shouldn't be used, generally. the only case where this is necessary is
# when we have a class which doesn't use the mop inheriting from a class which
# does. in that case, we need to inflate a basic metaclass for that class in
# order to be able to instantiate new instances via new_instance. see
# mop::object::new.
sub find_or_create_meta {
    my ($class) = @_;

    if (my $meta = find_meta($class)) {
        return $meta;
    }
    else {
        # creating a metaclass from an existing non-mop class
        my $stash = get_stash_for($class);

        my $name      = $stash->name;
        my $version   = $stash->get_symbol('$VERSION');
        my $authority = $stash->get_symbol('$AUTHORITY');
        my $isa       = $stash->get_symbol('@ISA');

        die "Multiple inheritance is not supported in mop classes"
            if @$isa > 1;

        my $new_meta = mop::class->new(
            name       => $name,
            version    => $version,
            authority  => $authority,
            superclass => $isa->[0],
        );

        for my $method ($stash->list_all_symbols('CODE')) {
            $new_meta->add_method(
                mop::method->new(
                    name => $method,
                    body => $stash->get_symbol('&' . $method),
                )
            );
        }

        # can't just use install_meta, because applying the mop mro to a
        # non-mop class will break things (SUPER, for instance)
        $stash->add_symbol('$METACLASS', \$new_meta);

        return $new_meta;
    }
}

sub apply_all_roles {
    my ($to, @roles) = @_;

    my $composite = _create_composite_role(@roles);

    $to->fire('before:CONSUME' => $composite);
    $composite->fire('before:COMPOSE' => $to);

    foreach my $attribute ($composite->attributes) {
        die 'Attribute conflict ' . $attribute->name . ' when composing ' . $composite->name . ' into ' . $to->name
            if $to->has_attribute( $attribute->name )
            && $to->get_attribute( $attribute->name )->conflicts_with( $attribute );
        $to->add_attribute( $attribute->clone(associated_meta => $to) );
    }

    foreach my $method ($composite->methods) {
        if (my $existing_method = $to->get_method($method->name)) {
            apply_metaclass($existing_method, $method);
        }
        else {
            $to->add_method($method->clone(associated_meta => $to));
        }
    }

    # merge required methods ...
    for my $conflict ($composite->required_methods) {
        if (my $method = $to->get_method($conflict)) {
            my @conflicting_methods =
                grep { $_->name eq $conflict }
                map { $_->methods }
                @{ $composite->roles };
            for my $conflicting_method (@conflicting_methods) {
                apply_metaclass($method, $conflicting_method);
            }
        }
        else {
            $to->add_required_method($conflict);
        }
    }

    $composite->fire('after:COMPOSE' => $to);
    $to->fire('after:CONSUME' => $composite);
}

sub _create_composite_role {
    my (@roles) = @_;

    return $roles[0] if @roles == 1;

    my $composite = mop::role->new(
        name  => 'COMPOSITE::OF::[' . (join ', ' => map { $_->name } @roles) . ']',
        roles => [ @roles ],
    );

    $composite->fire('before:CONSUME' => $_)
        for @roles;
    $_->fire('before:COMPOSE' => $composite)
        for @roles;

    {
        my %attributes;
        for my $role (@roles) {
            for my $attribute ($role->attributes) {
                my $name = $attribute->name;
                my $seen = $attributes{$name};
                die "Attribute conflict $name when composing "
                  . $seen->associated_meta->name . " with " . $role->name
                  if $seen && $seen->conflicts_with($attribute);
                $attributes{$name} = $attribute;
                $composite->add_attribute(
                    $attribute->clone(associated_meta => $composite)
                );
            }
        }
    }

    {
        my %methods;
        my %conflicts;
        for my $role (@roles) {
            for my $method ($role->methods) {
                my $name = $method->name;
                if ($conflicts{$name}) {
                    next;
                }
                elsif ($methods{$name}) {
                    next unless $methods{$name}->conflicts_with($method);
                    $conflicts{$name} = delete $methods{$name};
                }
                else {
                    $methods{$name} = $method;
                }
            }
        }
        for my $name (keys %methods) {
            $composite->add_method(
                $methods{$name}->clone(associated_meta => $composite)
            );
        }
        for my $requirement (keys %conflicts) {
            $composite->add_required_method($requirement);
        }
    }

    for my $role (@roles) {
        for my $requirement ($role->required_methods) {
            $composite->add_required_method($requirement)
                unless $composite->has_method($requirement);
        }
    }

    $_->fire('after:COMPOSE' => $composite)
        for @roles;
    $composite->fire('after:CONSUME' => $_)
        for @roles;

    return $composite;
}

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

my %NONMOP_CLASSES;

sub mark_nonmop_class {
    my ($class) = @_;
    $NONMOP_CLASSES{$class} = 1;
}

sub install_meta {
    my ($meta) = @_;

    die "Metaclasses must inherit from mop::class or mop::role"
        unless $meta->isa('mop::class') || $meta->isa('mop::role');

    my $name = $meta->name;

    die "The metaclass for $name has already been created"
        if find_meta($name);

    die "$name has already been used as a non-mop class. "
      . "Does your code have a circular dependency?"
        if $NONMOP_CLASSES{$name};

    my $stash = mop::util::get_stash_for($name);
    $stash->add_symbol('$METACLASS', \$meta);
    $stash->add_symbol('$VERSION', \$meta->version);
    mro::set_mro($name, 'mop');
}

sub uninstall_meta {
    my ($meta) = @_;

    die "Metaclasses must inherit from mop::class or mop::role"
        unless $meta->isa('mop::class') || $meta->isa('mop::role');

    my $stash = mop::util::get_stash_for($meta->name);
    $stash->remove_symbol('$METACLASS');
    $stash->remove_symbol('$VERSION');
    mro::set_mro($meta->name, 'dfs');
}

sub close_class {
    my ($class) = @_;

    my $new_meta = _get_class_for_closing($class);

    # XXX clear caches here if we end up adding any, and if we end up
    # implementing reopening of classes

    bless $class, $new_meta->name;
}

sub _get_class_for_closing {
    my ($class) = @_;

    my $class_meta = find_meta($class);

    my $closed_name = 'mop::closed::' . $class_meta->name;

    my $new_meta = find_meta($closed_name);
    return $new_meta if $new_meta;

    $new_meta = find_meta($class_meta)->new_instance(
        name       => $closed_name,
        version    => $class_meta->version,
        superclass => $class_meta->name,
        roles      => [],
    );
    install_meta($new_meta);

    my @mutable_methods = qw(
        add_attribute
        add_method
        add_required_method
        add_role
        add_submethod
        make_class_abstract
        remove_method
    );

    for my $method (@mutable_methods) {
        $new_meta->add_method(
            $new_meta->method_class->new(
                name => $method,
                body => sub { die "Can't call $method on a closed class" },
            )
        );
    }

    $new_meta->add_method(
        $new_meta->method_class->new(
            name => 'is_closed',
            body => sub { 1 },
        )
    );

    $new_meta->FINALIZE;

    my $stash = get_stash_for($class->name);
    for my $isa (@{ mop::mro::get_linear_isa($class->name) }) {
        if (has_meta($isa)) {
            for my $method (find_meta($isa)->methods) {
                $stash->add_symbol('&' . $method->name => $method->body);
            }
        }
    }

    return $new_meta;
}

sub fix_metaclass_compatibility {
    my ($meta, $super) = @_;

    my $meta_name  = blessed($meta) // $meta;
    return $meta_name if !defined $super; # non-mop inheritance

    my $super_name = blessed($super) // $super;

    # immutability is on a per-class basis, it shouldn't be inherited.
    # otherwise, subclasses of closed classes won't be able to do things
    # like add attributes or methods to themselves
    $meta_name = mop::get_meta($meta_name)->superclass
        if $meta_name->isa('mop::class') && $meta_name->is_closed;
    $super_name = mop::get_meta($super_name)->superclass
        if $super_name->isa('mop::class') && $super_name->is_closed;

    return $meta_name  if $meta_name->isa($super_name);
    return $super_name if $super_name->isa($meta_name);

    my $rebased_meta_name = _rebase_metaclasses($meta_name, $super_name);
    return $rebased_meta_name if $rebased_meta_name;

    my $meta_desc = blessed($meta)
        ? $meta->name . " ($meta_name)"
        : $meta_name;
    my $super_desc = blessed($super)
        ? $super->name . " ($super_name)"
        : $super_name;
    die "Can't fix metaclass compatibility between $meta_desc and $super_desc";
}

sub _rebase_metaclasses {
    my ($meta_name, $super_name) = @_;

    my $common_base = _find_common_base($meta_name, $super_name);
    return unless $common_base;

    my @meta_isa = @{ mop::mro::get_linear_isa($meta_name) };
    pop @meta_isa until $meta_isa[-1] eq $common_base;
    pop @meta_isa;
    @meta_isa = reverse map { find_meta($_) } @meta_isa;

    my @super_isa = @{ mop::mro::get_linear_isa($super_name) };
    pop @super_isa until $super_isa[-1] eq $common_base;
    pop @super_isa;
    @super_isa = reverse map { find_meta($_) } @super_isa;

    # XXX i just haven't thought through exactly what this would mean - this
    # restriction may be able to be lifted in the future
    return if grep { $_->is_abstract } @meta_isa, @super_isa;

    my %super_method_overrides    = map { %{ $_->method_map    } } @super_isa;
    my %super_attribute_overrides = map { %{ $_->attribute_map } } @super_isa;

    my $current = $super_name;
    for my $class (@meta_isa) {
        return if grep {
            $super_method_overrides{$_->name}
        } $class->methods;

        return if grep {
            $super_attribute_overrides{$_->name}
        } $class->attributes;

        my $class_name = $class->name;
        my $rebased = "mop::class::rebased::${class_name}::for::${current}";
        if (!has_meta($rebased)) {
            my $clone = $class->clone(
                name       => $rebased,
                superclass => $current,
            );
            install_meta($clone);
            close_class($clone);
        }
        $current = $rebased;
    }

    return $current;
}

sub _find_common_base {
    my ($meta_name, $super_name) = @_;

    my %meta_ancestors =
        map { $_ => 1 } @{ mop::mro::get_linear_isa($meta_name) };

    for my $super_ancestor (@{ mop::mro::get_linear_isa($super_name) }) {
        return $super_ancestor if $meta_ancestors{$super_ancestor};
    }

    return;
}

sub rebless ($;$) {
    my ($object, $into) = @_;

    my $from = Scalar::Util::blessed($object);
    my $common_base = mop::util::_find_common_base($from, $into);

    my @from_isa = @{ mop::mro::get_linear_isa($from) };
    if ($common_base) {
        pop @from_isa until $from_isa[-1] eq $common_base;
        pop @from_isa;
    }
    @from_isa = grep { defined } map { mop::util::find_meta($_) } @from_isa;

    my @into_isa = @{ mop::mro::get_linear_isa($into) };
    if ($common_base) {
        pop @into_isa until $into_isa[-1] eq $common_base;
        pop @into_isa;
    }
    @into_isa = grep { defined } map { mop::util::find_meta($_) } @into_isa;

    for my $attr (map { $_->attributes } @from_isa) {
        delete $attr->storage->{$object};
    }

    bless($object, $into);

    for my $attr (map { $_->attributes } reverse @into_isa) {
        $attr->store_default_in_slot_for($object);
    }

    $object
}

sub apply_metaclass {
    my ($instance, $new_meta) = @_;
    bless $instance, fix_metaclass_compatibility($new_meta, $instance);
}

sub dump_object {
    my ($obj) = @_;

    my %attributes = map {
        if (my $m = find_meta($_)) {
            %{ $m->attribute_map }
        }
    } reverse @{ mop::mro::get_linear_isa($obj) };

    my $temp = {
        __ID__    => get_object_id($obj),
        __CLASS__ => find_meta($obj)->name,
        __SELF__  => $obj,
    };

    foreach my $attr (values %attributes) {
        if ($attr->name eq '$storage') {
            $temp->{ $attr->name } = '__INTERNAL_DETAILS__';
        } else {
            $temp->{ $attr->name } = _dumper(
                $attr->fetch_data_in_slot_for( $obj )
            );
        }
    }

    $temp;
}

sub _dumper {
    my ($data) = @_;
    if (blessed($data)) {
        return dump_object($data);
    } elsif (ref $data) {
        if (ref $data eq 'ARRAY') {
            return [ map { _dumper( $_ ) } @$data ];
        } elsif (ref $data eq 'HASH') {
            return { map { $_ => _dumper( $data->{$_} ) } keys %$data };
        } else {
            return $data;
        }
    } else {
        return $data;
    }
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

