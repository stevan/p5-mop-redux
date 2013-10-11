#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use 5.016;

use mop;

class Foo is repr('HASH') {
    has $!attr = 'ATTR';

    method attr { $!attr }
    method foo  { 'FOO' }
    method bar  { 'BAR' }
}

{
    package Bar;
    use parent 'Foo';
    sub bar { 'BAZ' }
}

{
    my $bar = Bar->new;
    is($bar->attr, 'ATTR');
    is($bar->foo, 'FOO');
    is($bar->bar, 'BAZ');
}

{
    my $bar = Bar->new(attr => 'RTTA');
    is($bar->attr, 'RTTA');
    is($bar->foo, 'FOO');
    is($bar->bar, 'BAZ');
}

{
    package Baz;
    use parent 'Foo';
    sub bar { my $self = shift; $self->SUPER::bar . 'BAZ' }
}

{
    my $baz = Baz->new;
    is($baz->attr, 'ATTR');
    is($baz->foo, 'FOO');
    is($baz->bar, 'BARBAZ');
}

{
    my $baz = Baz->new(attr => 'RTTA');
    is($baz->attr, 'RTTA');
    is($baz->foo, 'FOO');
    is($baz->bar, 'BARBAZ');
}

{
    package Quux;
    use parent 'Foo';
    sub new {
        my $class = shift;
        my (%opts) = @_;

        my $self = $class->SUPER::new(%opts);
        $self->{extra} = $opts{extra} // 'EXTRA';

        return $self;
    }
    sub extra { $_[0]->{extra} }
}

{
    my $quux = Quux->new;
    is($quux->attr, 'ATTR');
    is($quux->extra, 'EXTRA');
}

{
    my $quux = Quux->new(attr => 'RTTA');
    is($quux->attr, 'RTTA');
    is($quux->extra, 'EXTRA');
}

{
    my $quux = Quux->new(extra => 'ARTXE');
    is($quux->attr, 'ATTR');
    is($quux->extra, 'ARTXE');
}

{
    my $quux = Quux->new(attr => 'RTTA', extra => 'ARTXE');
    is($quux->attr, 'RTTA');
    is($quux->extra, 'ARTXE');
}

class MyScalar is repr('SCALAR') {
    has $!attr is ro = 'MOP';
}

package MyScalar::Sub {
    use parent 'MyScalar';
    sub foo { my $self = shift; $$self = 'foo' }
}

{
    my $scalar = MyScalar::Sub->new;
    is($$scalar, undef);
    $scalar->foo;
    is($$scalar, 'foo');
    is($scalar->attr, 'MOP');
}

class MyArray is repr('ARRAY') {
    has $!attr is ro = 'MOP';
}

package MyArray::Sub {
    use parent 'MyArray';
    sub foo { my $self = shift; push @$self, @_ }
}

{
    my $array = MyArray::Sub->new;
    is_deeply([ @$array ], []);
    $array->foo(1, "foo");
    is_deeply([ @$array ], [1, "foo"]);
    $array->foo(2, "bar");
    is_deeply([ @$array ], [1, "foo", 2, "bar"]);
    is($array->attr, 'MOP');
}

class MyHash is repr('HASH') {
    has $!attr is ro = 'MOP';
}

package MyHash::Sub {
    use parent 'MyHash';
    sub foo { my $self = shift; $self->{$_[0]} = $_[1] }
}

{
    my $hash = MyHash::Sub->new;
    is_deeply({ %$hash }, {});
    $hash->foo('a', 1);
    is_deeply({ %$hash }, { a => 1 });
    $hash->foo('b', 2);
    is_deeply({ %$hash }, { a => 1, b => 2 });
    $hash->foo('a', 3);
    is_deeply({ %$hash }, { a => 3, b => 2 });
    is($hash->attr, 'MOP');
}

class MyGlob is repr('GLOB') {
    has $!attr is ro = 'MOP';
}

package MyGlob::Sub {
    use parent 'MyGlob';
    sub foo { my $self = shift; ${*$self}{$_[0]} = $_[1] }
}

{
    my $glob = MyGlob::Sub->new;
    is_deeply({ %{*$glob} }, {});
    $glob->foo('a', 1);
    is_deeply({ %{*$glob} }, { a => 1 });
    $glob->foo('b', 2);
    is_deeply({ %{*$glob} }, { a => 1, b => 2 });
    $glob->foo('a', 3);
    is_deeply({ %{*$glob} }, { a => 3, b => 2 });
    is($glob->attr, 'MOP');
}

class MyCustom is repr(sub { sub { state $x += $_[0] } }) {
    has $!attr is ro = 'MOP';
}

package MyCustom::Sub {
    use parent 'MyCustom';
    sub foo { my $self = shift; $self->($_[0]) }
}

{
    my $custom = MyCustom::Sub->new;
    is($custom->(0), 0);
    $custom->foo(1);
    is($custom->(0), 1);
    $custom->foo(2);
    is($custom->(0), 3);
    $custom->foo(3);
    is($custom->(0), 6);
    is($custom->attr, 'MOP');
}

eval '
class Error is repr("FOO") { }
';
like($@, qr/^unknown instance generator type FOO/);

eval '
class Error2 is repr([]) { }
';
like($@, qr/^unknown instance generator ARRAY\(/);

done_testing;
