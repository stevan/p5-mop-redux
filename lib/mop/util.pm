package mop::util;

use v5.16;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use mop::internals::util;
use mop::mro;

use Hash::Util::FieldHash;
use Scalar::Util;

use Exporter 'import';
our @EXPORT_OK = qw[
    find_meta
    has_meta
    remove_meta
    get_object_id
    is_mop_object
    apply_all_roles
    apply_metaclass
];

sub find_meta {
    ${ mop::internals::util::get_stash_for( shift )->get_symbol('$METACLASS') || \undef }
}

sub has_meta  {
    mop::internals::util::get_stash_for( shift )->has_symbol('$METACLASS')
}

sub remove_meta {
    mop::internals::util::get_stash_for( shift )->remove_symbol('$METACLASS')
}

sub get_object_id { Hash::Util::FieldHash::id( $_[0] ) }

sub is_mop_object {
    defined Hash::Util::FieldHash::id_2obj( get_object_id( $_[0] ) );
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

sub apply_metaclass {
    my ($instance, $new_meta) = @_;
    bless $instance, mop::internals::util::fix_metaclass_compatibility($new_meta, $instance);
}

sub _create_composite_role {
    my (@roles) = @_;

    return $roles[0] if @roles == 1;

    my $name = 'mop::role::COMPOSITE::OF::'
             . (join '::' => map { $_->name } @roles);
    return find_meta($name) if has_meta($name);

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

