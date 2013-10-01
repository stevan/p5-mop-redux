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

mop::traits::util

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
