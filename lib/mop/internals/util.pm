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

    my $new_meta = _get_class_for_closing($class);

    # XXX clear caches here if we end up adding any, and if we end up
    # implementing reopening of classes

    bless $class, $new_meta->name;
}

sub _get_class_for_closing {
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
