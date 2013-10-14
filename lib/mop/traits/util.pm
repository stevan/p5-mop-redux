package mop::traits::util;

use v5.16;
use warnings;

use Hash::Util::FieldHash qw[ fieldhash ];

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

fieldhash my %TRAIT_REGISTRATION;

sub apply_trait {
    my ($trait, $meta, @args) = @_;

    $trait->( $meta, @args );

    $TRAIT_REGISTRATION{ $meta } = []
        unless exists $TRAIT_REGISTRATION{ $meta };
    push @{ $TRAIT_REGISTRATION{ $meta } } => {
        trait => $trait,
        args  => \@args,
    };
}

sub applied_traits {
    my ($meta) = @_;
    return () unless exists $TRAIT_REGISTRATION{ $meta };
    return @{ $TRAIT_REGISTRATION{ $meta } };
}

1;

__END__

=pod

=head1 NAME

mop::traits::util - some utility functions for inspecting traits

=head1 DESCRIPTION

Since traits are simply subroutines that operate on meta-objects
it is not possible to inspect the meta-object to find out what
specific traits have been applied to it. This module aims to fix
that issue.

NOTE: This feature will likely become more sophisticated over time
and provide better introspection capabilities. What is here now is
just the beginning.

=head1 FUNCTIONS

=head2 C<apply_trait($trait, $meta, @args)>

Given a C<$trait> as a CODE ref, the C<$meta> object it is to be
applied too, and any C<@args>, this will perform the trait
application as well as registering this action.

=head2 C<applied_traits($meta)>

Given a C<$meta> object this will return the list of trait CODE
refs that were applied to it.

=head1 BUGS

Since this module is still under development we would prefer to not
use the RT bug queue and instead use the built in issue tracker on
L<Github|http://www.github.com>.

=head2 L<Git Repository|https://github.com/stevan/p5-mop-redux>

=head2 L<Issue Tracker|https://github.com/stevan/p5-mop-redux/issues>

=head1 AUTHOR

Stevan Little <stevan.little@iinteractive.com>

Jesse Luehrs <doy@tozt.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Infinity Interactive.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
