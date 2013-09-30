package mop::internals::util;
use v5.16;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Hash::Util::FieldHash;
use Package::Stash;

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

1;
