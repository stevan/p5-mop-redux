package mop::internals::util;
use v5.16;
use warnings;

use Hash::Util::FieldHash;
use Package::Stash;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

sub get_stash_for {
    state %STASHES;
    my $class = ref($_[0]) || $_[0];
    $STASHES{ $class } //= Package::Stash->new( $class )
}

sub init_attribute_storage (\%) {
    &Hash::Util::FieldHash::fieldhash( $_[0] )
}

sub register_object {
    Hash::Util::FieldHash::register( $_[0] )
}

{
    my %NONMOP_CLASSES;

    sub mark_nonmop_class {
        my ($class) = @_;
        $NONMOP_CLASSES{$class} = 1;
    }

    sub is_nonmop_class {
        my ($class) = @_;
        $NONMOP_CLASSES{$class};
    }
}

sub install_meta {
    my ($meta) = @_;

    my $name = $meta->name;

    die "The metaclass for $name has already been created"
        if mop::meta($name);

    die "$name has already been used as a non-mop class. "
      . "Does your code have a circular dependency?"
        if is_nonmop_class($name);

    my $stash = get_stash_for($name);
    $stash->add_symbol('$METACLASS', \$meta);
    mro::set_mro($name, 'mop');
}

sub finalize_meta {
    my ($meta) = @_;

    $meta->fire('before:FINALIZE');

    apply_all_roles($meta, @{ $meta->roles })
        if @{ $meta->roles };

    if ($meta->isa('mop::class')) {
        die 'Required method(s) [' . (join ', ' => $meta->required_methods)
            . '] are not allowed in ' . $meta->name
            . ' unless class is declared abstract'
            if $meta->required_methods && not $meta->is_abstract;
    }

    my $stash = mop::internals::util::get_stash_for($meta->name);
    $stash->add_symbol('$VERSION', \$meta->version);

    $meta->fire('after:FINALIZE');
}

sub apply_all_roles {
    my ($to, @roles) = @_;

    my $composite = create_composite_role(@roles);

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
            mop::apply_metaclass($existing_method, $method);
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
                mop::apply_metaclass($method, $conflicting_method);
            }
        }
        else {
            $to->add_required_method($conflict);
        }
    }

    $composite->fire('after:COMPOSE' => $to);
    $to->fire('after:CONSUME' => $composite);
}

sub close_class {
    my ($class) = @_;

    my $new_meta = get_class_for_closing($class);

    # XXX clear caches here if we end up adding any, and if we end up
    # implementing reopening of classes

    bless $class, $new_meta->name;
}

sub get_class_for_closing {
    my ($class) = @_;

    my $class_meta = mop::meta($class);

    my $closed_name = 'mop::closed::' . $class_meta->name;

    my $new_meta = mop::meta($closed_name);
    return $new_meta if $new_meta;

    $new_meta = mop::meta($class_meta)->new_instance(
        name       => $closed_name,
        version    => $class_meta->version,
        superclass => $class_meta->name,
        roles      => [],
    );

    my @mutator_methods = qw(
        add_role
        add_attribute
        add_method
        add_required_method
        remove_required_method
        make_class_abstract
        set_instance_generator
        add_submethod
    );

    for my $method (@mutator_methods) {
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
        if (mop::meta($isa)) {
            for my $method (mop::meta($isa)->methods) {
                $stash->add_symbol('&' . $method->name => $method->body);
            }
        }
    }

    return $new_meta;
}

# this shouldn't be used, generally. the only case where this is necessary is
# when we have a class which doesn't use the mop inheriting from a class which
# does. in that case, we need to inflate a basic metaclass for that class in
# order to be able to instantiate new instances via new_instance. see
# mop::object::new.
sub find_or_inflate_meta {
    my ($class) = @_;

    if (my $meta = mop::meta($class)) {
        return $meta;
    }
    else {
        return inflate_meta($class);
    }
}

sub inflate_meta {
    my ($class) = @_;

    my $stash = get_stash_for($class);

    my $name      = $stash->name;
    my $version   = $stash->get_symbol('$VERSION');
    my $authority = $stash->get_symbol('$AUTHORITY');
    my $isa       = $stash->get_symbol('@ISA');

    die "Multiple inheritance is not supported in mop classes"
        if @$isa > 1;

    # can't use the mop mro for non-mop classes, it confuses things like SUPER
    my $mro = mro::get_mro($name);
    my $new_meta = mop::class->new(
        name       => $name,
        version    => $version,
        authority  => $authority,
        superclass => $isa->[0],
    );
    mro::set_mro($name, $mro);

    for my $method ($stash->list_all_symbols('CODE')) {
        $new_meta->add_method(
            mop::method->new(
                name => $method,
                body => $stash->get_symbol('&' . $method),
            )
        );
    }

    return $new_meta;
}

sub fix_metaclass_compatibility {
    my ($meta, $super) = @_;

    my $meta_name  = Scalar::Util::blessed($meta) // $meta;
    return $meta_name if !defined $super; # non-mop inheritance

    my $super_name = Scalar::Util::blessed($super) // $super;

    # immutability is on a per-class basis, it shouldn't be inherited.
    # otherwise, subclasses of closed classes won't be able to do things
    # like add attributes or methods to themselves
    $meta_name = mop::meta($meta_name)->superclass
        if $meta_name->isa('mop::class') && $meta_name->is_closed;
    $super_name = mop::meta($super_name)->superclass
        if $super_name->isa('mop::class') && $super_name->is_closed;

    return $meta_name  if $meta_name->isa($super_name);
    return $super_name if $super_name->isa($meta_name);

    my $rebased_meta_name = rebase_metaclasses($meta_name, $super_name);
    return $rebased_meta_name if $rebased_meta_name;

    my $meta_desc = Scalar::Util::blessed($meta)
        ? $meta->name . " ($meta_name)"
        : $meta_name;
    my $super_desc = Scalar::Util::blessed($super)
        ? $super->name . " ($super_name)"
        : $super_name;
    die "Can't fix metaclass compatibility between $meta_desc and $super_desc";
}

sub rebase_metaclasses {
    my ($meta_name, $super_name) = @_;

    my $common_base = find_common_base($meta_name, $super_name);
    return unless $common_base;

    my @meta_isa = @{ mop::mro::get_linear_isa($meta_name) };
    pop @meta_isa until $meta_isa[-1] eq $common_base;
    pop @meta_isa;
    @meta_isa = reverse map { mop::meta($_) } @meta_isa;

    my @super_isa = @{ mop::mro::get_linear_isa($super_name) };
    pop @super_isa until $super_isa[-1] eq $common_base;
    pop @super_isa;
    @super_isa = reverse map { mop::meta($_) } @super_isa;

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
        if (!mop::meta($rebased)) {
            my $clone = $class->clone(
                name       => $rebased,
                superclass => $current,
            );
            mop::traits::closed($clone);
            $clone->FINALIZE;
        }
        $current = $rebased;
    }

    return $current;
}

sub find_common_base {
    my ($meta_name, $super_name) = @_;

    my %meta_ancestors =
        map { $_ => 1 } @{ mop::mro::get_linear_isa($meta_name) };

    for my $super_ancestor (@{ mop::mro::get_linear_isa($super_name) }) {
        return $super_ancestor if $meta_ancestors{$super_ancestor};
    }

    return;
}

sub create_composite_role {
    my (@roles) = @_;

    return $roles[0] if @roles == 1;

    my $name = 'mop::role::COMPOSITE::OF::'
             . (join '::' => map { $_->name } @roles);
    return mop::meta($name) if mop::meta($name);

    my $composite = mop::role->new(
        name  => $name,
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

1;
