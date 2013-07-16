package mop::object;

use v5.16;
use warnings;

use mop::util    qw[ find_meta get_object_id ];
use Scalar::Util qw[ blessed ];

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

sub new {
    my $class = shift;
    my %args  = @_;

    my $self = bless \(my $x) => $class;

    # NOTE:
    # prior to the bootstrapping being
    # finished, we need to not try and
    # build classes, it will all be done
    # manually in the mop:: classes.
    # - SL
    return $self unless $mop::BOOTSTRAPPED;

    my $meta = find_meta($class);

    die 'Cannot instantiate abstract class (' . $class . ')'
        if $meta->is_abstract;

    my @mro = @{ mop::mro::get_linear_isa($class) };

    my %attributes = map {
        if (my $m = find_meta($_)) {
            %{ $m->attributes }
        }
    } reverse @mro;

    foreach my $attr (values %attributes) {
        if ( exists $args{ $attr->key_name }) {
            $attr->store_data_in_slot_for( $self, $args{ $attr->key_name } )
        } else {
            $attr->store_default_in_slot_for( $self );
        }
    }

    $self->BUILDALL( \%args );

    $self;
}

sub BUILDALL {
    my ($self, @args) = @_;
    foreach my $class (reverse @{ mop::mro::get_linear_isa($self) }) {
        if (my $m = find_meta($class)) {
            $m->get_submethod('BUILD')->execute($self, [ @args ])
                if $m->has_submethod('BUILD');
        }
    }
}

sub id { get_object_id( shift ) }

sub dump {
    my $self = shift;

    my %attributes = map {
        if (my $m = find_meta($_)) {
            %{ $m->attributes }
        }
    } reverse @{ mop::mro::get_linear_isa($self) };

    my $temp = {
        __ID__    => get_object_id($self),
        __CLASS__ => find_meta($self)->name,
        __SELF__  => $self,
    };

    foreach my $attr (values %attributes) {
        if ($attr->name eq '$storage') {
            $temp->{ $attr->name } = '__INTERNAL_DETAILS__';
        } else {
            $temp->{ $attr->name } = _dumper(
                $attr->fetch_data_in_slot_for( $self )
            );
        }
    }

    $temp;
}

sub _dumper {
    my ($data) = @_;
    if (blessed($data)) {
        return $data->dump;
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

sub does {
    my ($self, $role) = @_;
    scalar grep { find_meta($_)->does_role($role) } @{ mop::mro::get_linear_isa($self) }
}

sub DOES {
    my ($self, $role) = @_;
    $self->does($role) or $self->isa($role) or $role eq q(UNIVERSAL);
}

sub DESTROY {
    my $self = shift;
    foreach my $class (@{ mop::mro::get_linear_isa($self) }) {
        if (my $m = find_meta($class)) {
            $m->get_submethod('DEMOLISH')->execute($self, [])
                if $m->has_submethod('DEMOLISH');
        }
    }
}

our $METACLASS;

sub __INIT_METACLASS__ {
    return $METACLASS if defined $METACLASS;
    require mop::class;
    $METACLASS = mop::class->new(
        name      => 'mop::object',
        version   => $VERSION,
        authority => $AUTHORITY,
    );
    $METACLASS->add_method( mop::method->new( name => 'new',       body => \&new ) );
    $METACLASS->add_method( mop::method->new( name => 'BUILDALL',  body => \&BUILDALL ) );
    $METACLASS->add_method( mop::method->new( name => 'id',        body => \&id ) );
    $METACLASS->add_method( mop::method->new( name => 'dump',      body => \&dump ) );
    $METACLASS->add_method( mop::method->new( name => 'does',      body => \&does ) );
    $METACLASS->add_method( mop::method->new( name => 'DOES',      body => \&DOES ) );
    $METACLASS->add_method( mop::method->new(
        name => 'isa',
        body => sub {
            my ($self, $class) = @_;
            return 0 unless defined $class; # WTF perl!
            scalar grep { $class eq $_ } @{ mop::mro::get_linear_isa($self) }
        }
    ));
    $METACLASS->add_method( mop::method->new(
        name => 'can',
        body => sub {
            my ($self, $method_name) = @_;
            if (my $method = mop::internals::mro::find_method($self, $method_name)) {
                return blessed($method) ? $method->body : $method;
            }
        }
    ));
    $METACLASS->add_method( mop::method->new( name => 'DESTROY', body => \&DESTROY ) );
    $METACLASS;
}

1;

__END__

=pod

=head1 NAME

mop::object

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





