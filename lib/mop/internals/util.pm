package mop::internals::util;
use v5.16;
use warnings;

use Hash::Util::FieldHash;
use mro ();
use Scalar::Util ();

our $VERSION   = '0.02';
our $AUTHORITY = 'cpan:STEVAN';

# XXX all of this OVERRIDDEN stuff really needs to go, ideally replaced by
# lexical exports
my %OVERRIDDEN;

sub install_sub {
    my ($to, $from, $sub) = @_;
    no strict 'refs';
    if (*{ "${to}::${sub}" }) {
        push @{ $OVERRIDDEN{$to}{$sub} //= [] }, \&{ "${to}::${sub}" };
    }
    no warnings 'redefine';
    *{ $to . '::' . $sub } = \&{ "${from}::${sub}" };
}

sub uninstall_sub {
    my ($pkg, $sub) = @_;
    no strict 'refs';
    delete ${ $pkg . '::' }{$sub};
    if (my $prev = pop @{ $OVERRIDDEN{$pkg}{$sub} // [] }) {
        *{ $pkg . '::' . $sub } = $prev;
    }
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

    set_meta($name, $meta);

    $INC{ ($name =~ s{::}{/}gr) . '.pm' } //= '(mop)';
}

sub apply_all_roles {
    my ($to, @roles) = @_;

    unapply_all_roles($to);

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

sub unapply_all_roles {
    my ($meta) = @_;

    for my $attr ($meta->attributes) {
        $meta->remove_attribute($attr->name)
            unless $attr->locally_defined;
    }

    for my $method ($meta->methods) {
        $meta->remove_method($method->name)
            unless $method->locally_defined;
    }

    # XXX this is wrong, it will also remove required methods that were
    # defined in the class directly
    $meta->remove_required_method($_)
        for $meta->required_methods;
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

    my $name      = $class;
    my $version   = do { no strict 'refs'; ${ *{ $class . '::VERSION' }{SCALAR} } };
    my $authority = do { no strict 'refs'; ${ *{ $class . '::AUTHORITY' }{SCALAR} } };
    my $isa       = do { no strict 'refs'; *{ $class . '::ISA' }{ARRAY} };

    die "Multiple inheritance is not supported in mop classes"
        if @$isa > 1;

    my $new_meta = mop::class->new(
        name       => $name,
        version    => $version,
        authority  => $authority,
        superclass => $isa->[0],
    );

    for my $method (do { no strict 'refs'; keys %{ $class . '::' } }) {
        next unless $class->can($method);
        $new_meta->add_method(
            mop::method->new(
                name => $method,
                body => $class->can($method),
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

    my @meta_isa = @{ mro::get_linear_isa($meta_name) };
    pop @meta_isa until $meta_isa[-1] eq $common_base;
    pop @meta_isa;
    @meta_isa = reverse map { mop::meta($_) } @meta_isa;

    my @super_isa = @{ mro::get_linear_isa($super_name) };
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
            $clone->FINALIZE;
        }
        $current = $rebased;
    }

    return $current;
}

sub find_common_base {
    my ($meta_name, $super_name) = @_;

    my %meta_ancestors =
        map { $_ => 1 } @{ mro::get_linear_isa($meta_name) };

    for my $super_ancestor (@{ mro::get_linear_isa($super_name) }) {
        return $super_ancestor if $meta_ancestors{$super_ancestor};
    }

    return;
}

sub create_composite_role {
    my (@roles) = @_;

    @roles = map { ref($_) ? $_ : mop::meta($_) } @roles;

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

sub buildall {
    my ($instance, @args) = @_;

    foreach my $class (reverse @{ mro::get_linear_isa(ref $instance) }) {
        if (my $m = mop::meta($class)) {
            $m->get_method('BUILD')->execute($instance, [ @args ])
                if $m->has_method('BUILD');
        }
    }
}

1;

__END__

=pod

=head1 NAME

mop::internals::util - internal use only

=head1 DESCRIPTION

This is for internal use only, there is no public API here.

=head1 BUGS

Since this module is still under development we would prefer to not
use the RT bug queue and instead use the built in issue tracker on
L<Github|http://www.github.com>.

=head2 L<Git Repository|https://github.com/stevan/p5-mop-redux>

=head2 L<Issue Tracker|https://github.com/stevan/p5-mop-redux/issues>

=head1 AUTHOR

Stevan Little <stevan.little@iinteractive.com>

Jesse Luehrs <doy@tozt.net>

Florian Ragwitz <rafl@debian.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Infinity Interactive.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=for Pod::Coverage .+

=cut
