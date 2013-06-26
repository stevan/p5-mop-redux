#!perl

use strict;
use warnings;

use Test::More;

=pod

A long, long time ago ... in a galaxy far, far away ... http://svn.openfoundry.org/pugs/ext/Test-Builder

So, back in the heydays of Pugs, chromatic
decided to experiment and port Test::Builder
to Perl 6. Fast forward many years into the
future ... and I decided I needed an example
for the p5mop that was sufficiently complex
enough to test features and show-off some of
the syntactic sweetness. I think this has
actually succeded quite well in accomplishing
this. Some notable features are:

=over 4

=item ArrayRef attributes

The syntax to operate on them is kind of
nice (in my opinion anyway):

  push @$results => $test

This can be seen in the Test::BuilderX
class in particular.

=item Using defined-or (//) in BUILD

See Test::BuilderX::BUILD for an example.

=item Multiple classes per-file

See both Test::BuilderX::TestPlan and
Test::BuilderX::Test for an example.

=item Using old style Perl OO as a factory

If you look in Test::BuilderX::Test, the &new
method is just a factory for constructing the
new MOP powered classes. This is a nice mix of
the two styles in my opinion.

=item Mixing procedural with new OO

See Test::BuilderX::Tester for an example of
this. Again, I think this shows how the new
style classes can compliment old style perl.

=back

=cut

use lib 't/ext/Test-BuilderX';

BEGIN {
    use_ok( 'Test::BuilderX' );
    use_ok( 'Test::BuilderX::Tester' );
}

done_testing;


