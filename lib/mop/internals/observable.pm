package mop::internals::observable;

use v5.16;
use warnings;

use mop::internals::util;

our $VERSION   = '0.01';
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
        "$_" ne "$callback"
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

our $METACLASS;

sub __INIT_METACLASS__ {
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
    $METACLASS;
}

1;

__END__

=pod

=head1 NAME

mop::method

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





