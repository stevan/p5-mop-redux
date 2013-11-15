package main;
use strict;
use warnings;

use mop;

class Baz {
    has $!bar = 'Baz::bar';
    has $!baz = 'Baz::baz';

    method bar    { $!bar }
    method baz    { $!baz }
    method const  { 1 }
    method concat { $!bar . $!baz }
}

1;
