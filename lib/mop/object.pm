package mop::object;

use v5.16;
use warnings;

use mop::internals::util;

our $VERSION   = '0.03';
our $AUTHORITY = 'cpan:STEVAN';

sub new {
    my $class = shift;

    # NOTE:
    # prior to the bootstrapping being
    # finished, we need to not try to
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

sub does {
    my ($self, $role) = @_;
    scalar grep { mop::meta($_)->does_role($role) } @{ mro::get_linear_isa(ref($self) || $self) }
}

sub DOES {
    my ($self, $role) = @_;
    $self->does($role) or $self->UNIVERSAL::DOES($role);
}

sub DESTROY {
    my $self = shift;
    foreach my $class (@{ mro::get_linear_isa(ref $self) }) {
        if (my $m = mop::meta($class)) {
            $m->get_method('DEMOLISH')->execute($self, [])
                if $m->has_method('DEMOLISH');
        }
    }
}

sub __INIT_METACLASS__ {
    my $METACLASS = mop::class->new(
        name      => 'mop::object',
        version   => $VERSION,
        authority => $AUTHORITY,
    );

    $METACLASS->add_method(
        mop::method->new(
            name => 'new',
            body => sub {
                my $class = shift;
                my (%args) = @_ == 1 && ref $_[0] eq 'HASH' ? %{$_[0]} : @_;
                mop::internals::util::find_or_inflate_meta($class)->new_instance(%args);
            }
        )
    );

    $METACLASS->add_method( mop::method->new( name => 'clone', body => \&clone ) );

    $METACLASS->add_method( mop::method->new( name => 'does', body => \&does ) );
    $METACLASS->add_method( mop::method->new( name => 'DOES', body => \&DOES ) );

    $METACLASS->add_method( mop::method->new( name => 'DESTROY', body => \&DESTROY ) );

    $METACLASS;
}

1;

__END__

=pod

=head1 NAME

mop::object - A base object for mop classes

=head1 DESCRIPTION

TODO

=head1 METHODS

=over 4

=item C<new(@args)>

=item C<clone(%overrides)>

=item C<does($role_name)>

=item C<DOES($class_or_role_name)>

=item C<DESTROY>

=back

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

This software is copyright (c) 2013-2014 by Infinity Interactive.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
