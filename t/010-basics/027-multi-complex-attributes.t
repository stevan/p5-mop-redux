#!perl

use strict;
use warnings;

use Test::More;

use mop;

=pod

...

=cut

class Bar {}
class Baz {}

class Foo {
    has $!bar = Bar->new;
    has $!baz = Baz->new;

    method bar { $!bar }
    method has_bar      { defined $!bar }
    method set_bar ($b) { $!bar = $b  }
    method clear_bar    { undef $!bar }

    method baz { $!baz }
    method has_baz      { defined $!baz }
    method set_baz ($b) { $!baz = $b  }
    method clear_baz    { undef $!baz }

}

{
    my $foo = Foo->new;
    ok( $foo->isa( 'Foo' ), '... the object is from class Foo' );

    ok($foo->has_bar, '... bar is set as a default');
    ok($foo->bar->isa( 'Bar' ), '... value isa Bar object');

    ok($foo->has_baz, '... baz is set as a default');
    ok($foo->baz->isa( 'Baz' ), '... value isa Baz object');

    my $bar = $foo->bar;
    my $baz = $foo->baz;

    #diag $bar;
    #diag $baz;

    eval { $foo->set_bar( Bar->new ) };
    is($@, "", '... set bar without error');
    ok($foo->has_bar, '... bar is set');
    ok($foo->bar->isa( 'Bar' ), '... value is set by the set_bar method');
    isnt($foo->bar, $bar, '... the new value has been set');

    eval { $foo->set_baz( Baz->new ) };
    is($@, "", '... set baz without error');
    ok($foo->has_baz, '... baz is set');
    ok($foo->baz->isa( 'Baz' ), '... value is set by the set_baz method');
    isnt($foo->baz, $baz, '... the new value has been set');

    eval { $foo->clear_bar };
    is($@, "", '... set bar without error');
    ok(!$foo->has_bar, '... no bar is set');
    is($foo->bar, undef, '... values has been cleared');

    eval { $foo->clear_baz };
    is($@, "", '... set baz without error');
    ok(!$foo->has_baz, '... no baz is set');
    is($foo->baz, undef, '... values has been cleared');
}


done_testing;
