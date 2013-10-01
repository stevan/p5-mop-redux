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
        if mop::util::find_meta($name);

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

    mop::util::apply_all_roles($meta, @{ $meta->roles })
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

sub close_class {
    my ($class) = @_;

    my $new_meta = get_class_for_closing($class);

    # XXX clear caches here if we end up adding any, and if we end up
    # implementing reopening of classes

    bless $class, $new_meta->name;
}

sub get_class_for_closing {
    my ($class) = @_;

    my $class_meta = mop::util::find_meta($class);

    my $closed_name = 'mop::closed::' . $class_meta->name;

    my $new_meta = mop::util::find_meta($closed_name);
    return $new_meta if $new_meta;

    $new_meta = mop::util::find_meta($class_meta)->new_instance(
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
        if (mop::util::has_meta($isa)) {
            for my $method (mop::util::find_meta($isa)->methods) {
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

    if (my $meta = mop::util::find_meta($class)) {
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
    $meta_name = mop::util::find_meta($meta_name)->superclass
        if $meta_name->isa('mop::class') && $meta_name->is_closed;
    $super_name = mop::util::find_meta($super_name)->superclass
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
    @meta_isa = reverse map { mop::util::find_meta($_) } @meta_isa;

    my @super_isa = @{ mop::mro::get_linear_isa($super_name) };
    pop @super_isa until $super_isa[-1] eq $common_base;
    pop @super_isa;
    @super_isa = reverse map { mop::util::find_meta($_) } @super_isa;

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
        if (!mop::util::has_meta($rebased)) {
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

1;
