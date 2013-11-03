#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

eval '
class Foo {
    has $!bar = [];
    method get_bar ($i) { $!bar[$i] }
}
';
like($@, qr/No such twigil variable \@!bar/);

eval '
class Foo {
    has $!bar = [];
    method get_bar ($i) { $!bar  [$i] }
}
';
like($@, qr/No such twigil variable \@!bar/);

eval '
class Foo {
    has $!bar = {};
    method get_bar ($k) { $!bar{$k} }
}
';
like($@, qr/No such twigil variable \%!bar/);

eval '
class Foo {
    has $!bar = {};
    method get_bar ($k) { $!bar  {$k} }
}
';
like($@, qr/No such twigil variable \%!bar/);

done_testing;
