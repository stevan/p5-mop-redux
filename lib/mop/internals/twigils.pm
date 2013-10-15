package mop::internals::twigils;

require 5.014;
use strict;
use warnings;
use Carp 'croak';
use Devel::CallParser;
use Exporter ();

our @EXPORT = ('intro_twigil_my_var');

sub intro_twigil_my_var {
    croak "intro_twigil_my_var called as a function";
}

sub import {
    my ($class, @opts) = @_;

    $^H{__PACKAGE__ . '/twigils'} = 1;

    goto &Exporter::import;
}

1;
