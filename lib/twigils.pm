package twigils;
# ABSTRACT: Perl 6 style twigils for Perl 5

require 5.012;
use strict;
use warnings;
use XSLoader;
use Carp 'croak';
use Devel::CallChecker;

=func intro_twigil_my_var $varname

  intro_twigil_my_var '$!foo';

Introduces a new lexical twigil variable. Similar to perl's built-in C<my>
keyword, except it expects a string containing the variable name.

=cut

sub intro_twigil_my_var {
    croak "intro_twigil_my_var called as a function";
}

=func intro_twigil_state_var $varname

  intro_twigil_state_var '$!foo';

Introduces a new lexical twigil state variable. Similar to perl's built-in
C<state> keyword, except it expects a string containing the variable name.

=cut

sub intro_twigil_state_var {
    croak "intro_twigil_state_var called as a function";
}

=func intro_twigil_our_var $varname

  intro_twigil_our_var '$!foo';

Introduces a new lexical twigil variable as an alias to a package
variable. Similar to perl's built-in C<our> keyword, except it expects a string
containing the variable name.

=cut

sub intro_twigil_our_var {
    croak "intro_twigil_our_var called as a function";
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

=head1 CAVEATS

=for :list
* Only scalars are supported
This limitation might be removed in the future.
* Special punctuation variables and alphanumeric infix operators
Code such as C<$.eq 42> would normally be interpreted as comparing the contents
of the special variable C<$.> with the constant C<42> using the C<eq> infix
operator. However, in the presence of a twigil variable who's name consists of a
special variable name followed by the name of an infix operator (e.g. C<$.eq>)
an expression like C<$.eq 42> will be interpreted as a lookup of the variable
C<$.eq> followed by a constant C<42>, which will result in a syntax error. To
disambiguate between these two possible interpretations, use extra whitespace
between the special variable and the infix operator, i.e. C<$. eq 42>.
* Spaces between twigil and the variable identifier are forbidden
As a consequence of the above caveat, it's not possible to use any whitespace
between the twigil and the variable identifier, as is possible with perls
built-in lexical variables: C<$ foo> references the variable C<$foo>. C<$!  foo>
will most likely cause a compile time error.
* Long-hand dereferencing syntax is required
When storing references in twigil variables, the long-hand circumfix
dereferencing notation has to be used. C<@$!foo> doesn't cause the twigil
variable C<$!foo> to be dereferenced as an array. C<@{ $!foo }>, however, does.

=cut

1;
