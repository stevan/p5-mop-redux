package mop::internals::twigils;

require 5.014;
use strict;
use warnings;
use Carp 'croak';
use Devel::CallParser;
use Exporter ();

our @EXPORT = map { "intro_twigil_${_}_var" } qw(my state our);

sub intro_twigil_my_var {
    croak "intro_twigil_my_var called as a function";
}

sub intro_twigil_state_var {
    croak "intro_twigil_state_var called as a function";
}

sub intro_twigil_our_var {
    croak "intro_twigil_our_var called as a function";
}

sub import {
    my ($class, @opts) = @_;

    @_ = ($class);
    while (my $opt = shift @opts) {
        if ($opt eq 'fatal_lookup_errors') {
            $^H{__PACKAGE__ . '/not_in_pad_fatal'} = 1;
        }
        elsif ($opt eq 'allowed_twigils') {
            $^H{__PACKAGE__ . '/no_autovivification'} = 1;
            $^H{__PACKAGE__ . '/twigils'} = shift @opts;
        }
        else {
            push @_, $opt;
        }
    }

    goto &Exporter::import;
}

sub _add_allowed_twigil {
    my ($twigil) = @_;

    my %h = map {
        ($_ => 1)
    } (split '', $^H{ __PACKAGE__ . '/twigils' } || '');

    $^H{__PACKAGE__ . '/twigils'} = join '' => $twigil, keys %h;
}

1;
