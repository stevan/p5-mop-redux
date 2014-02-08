package op;

use v5.16;
use warnings;

require mop;
*import = \&mop::import;

our $VERSION   = '0.03';
our $AUTHORITY = 'cpan:STEVAN';

1;

__END__

=head1 NAME

op - syntactic sugar to make mop one-liners easier

=head1 VERSION

0.03

=head1 SYNOPSIS

    # Use mop on the fly
    perl -Mop -e 'class Point { has $!x is ro = 0; has $!y is ro = 0; method display { print "$!x, $!y" } } my $x = Point->new(x => 5, y => 7); $x->display'

=head1 DESCRIPTION

op.pm is a simple wrapper around L<mop.pm> that aliases its own C<import()> to
C<< mop->import >>, allowing you to do C<< perl -Mop >> rather than
C<< perl -Mmop >>.

It is recommended that you do not C<use> this in an actual file.

=head1 SEE ALSO

L<mop> - A new object system for Perl 5

=head1 AUTHOR

Matthew Horsfall (alh) <wolfsage@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013-2014 by Infinity Interactive.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
