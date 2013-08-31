package twigils;
# ABSTRACT: Perl 6 style twigils for Perl 5

require 5.012;
use strict;
use warnings;
use XSLoader;
use Carp 'croak';
use Devel::CallChecker;

=func intro_twigil_var $varname

  intro_twigil_var '$!foo';

Introduces a new twigil variable. Similar to perl's built-in C<my> keyword,
except it currently takes a string containing the variable name. This might
change in the future to make it more similar to C<my>.

=cut

sub intro_twigil_my_var {
    croak "intro_twigil_my_var called as a function";
}

XSLoader::load(
    __PACKAGE__,
    exists $twigil::{VERSION} ? ${ $twigil::{VERSION} } : (),
);

sub _add_allowed_twigil {
    my ($twigil) = @_;

    my %h = map {
        ($_ => 1)
    } (split '', $^H{ __PACKAGE__ . '/twigils' } || '');

    $^H{__PACKAGE__ . '/twigils'} = join '' => $twigil, keys %h;
}

1;
