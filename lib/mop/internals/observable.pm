package mop::internals::observable;

use v5.16;
use warnings;

use Scalar::Util qw[ refaddr ];

use mop::internals::util;

our $VERSION   = '0.02';
our $AUTHORITY = 'cpan:STEVAN';

mop::internals::util::init_attribute_storage(my %callbacks);

sub bind {
    my ($self, $event_name, $callback) = @_;
    $callbacks{ $self } = \{}
        unless $callbacks{ $self };
    ${$callbacks{ $self }}->{ $event_name } = []
        unless exists ${$callbacks{ $self }}->{ $event_name };
    push @{ ${$callbacks{ $self }}->{ $event_name } } => $callback;
    $self;
}

sub unbind {
    my ($self, $event_name, $callback) = @_;
    return $self unless $callbacks{ $self };
    return $self unless ${$callbacks{ $self }}->{ $event_name };
    @{ ${$callbacks{ $self }}->{ $event_name } } = grep {
        refaddr($_) != refaddr($callback)
    } @{ ${$callbacks{ $self }}->{ $event_name } };
    $self;
}

sub fire {
    my ($self, $event_name, @args) = @_;
    return $self unless $callbacks{ $self };
    return $self unless ${$callbacks{ $self }}->{ $event_name };
    $self->$_( @args ) foreach @{ ${$callbacks{ $self }}->{ $event_name } };
    return $self;
}

sub has_events {
    my $self = shift;
    return $callbacks{ $self } && !!%{ ${ $callbacks{ $self } } };
}

sub __INIT_METACLASS__ {
    state $METACLASS;
    return $METACLASS if defined $METACLASS;
    require mop::role;
    $METACLASS = mop::role->new(
        name       => 'mop::observable',
        version    => $VERSION,
        authority  => $AUTHORITY
    );

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!callbacks',
        storage => \%callbacks
    ));

    $METACLASS->add_method( mop::method->new( name => 'bind',   body => \&bind   ) );
    $METACLASS->add_method( mop::method->new( name => 'unbind', body => \&unbind ) );
    $METACLASS->add_method( mop::method->new( name => 'fire',   body => \&fire   ) );

    $METACLASS->add_method( mop::method->new( name => 'has_events', body => \&has_events ) );

    $METACLASS;
}

1;

__END__

=pod

=head1 NAME

mop::internals::observable - internal use only

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





