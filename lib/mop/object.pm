package mop::object;

use v5.16;
use warnings;

use Scalar::Util qw[ blessed ];

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

sub new {
    my $class = shift;

    # NOTE:
    # prior to the bootstrapping being
    # finished, we need to not try and
    # build classes, it will all be done
    # manually in the mop:: classes.
    # this method will be replaced once
    # bootstrapping is done.
    # - SL
    my $self = bless \(my $x) => $class;

    mop::internals::util::register_object( $self );

    return $self;
}

sub clone {
    my ($self, %args) = @_;
    return mop::meta($self)->clone_instance($self, %args);
}

sub BUILDALL {
    my ($self, @args) = @_;
    foreach my $class (reverse @{ mop::mro::get_linear_isa($self) }) {
        if (my $m = mop::meta($class)) {
            $m->get_method('BUILD')->execute($self, [ @args ])
                if $m->has_method('BUILD');
        }
    }
}

sub does {
    my ($self, $role) = @_;
    scalar grep { mop::meta($_)->does_role($role) } @{ mop::mro::get_linear_isa($self) }
}

sub DOES {
    my ($self, $role) = @_;
    $self->does($role) or $self->isa($role) or $role eq q(UNIVERSAL);
}

sub DESTROY {
    my $self = shift;
    foreach my $class (@{ mop::mro::get_linear_isa($self) }) {
        if (my $m = mop::meta($class)) {
            $m->get_method('DEMOLISH')->execute($self, [])
                if $m->has_method('DEMOLISH');
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
    $METACLASS->add_method( mop::method->new( name => 'clone',     body => \&clone ) );
    $METACLASS->add_method( mop::method->new( name => 'BUILDALL',  body => \&BUILDALL ) );
    $METACLASS->add_method( mop::method->new( name => 'does',      body => \&does ) );
    $METACLASS->add_method( mop::method->new( name => 'DOES',      body => \&DOES ) );
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





