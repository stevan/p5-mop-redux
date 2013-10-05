#!perl

use strict;
use warnings;

use Test::More;

use mop;

role Service {
    method is_locked { 0 }
}

role WithClass        with Service {}
role WithParameters   with Service {}
role WithDependencies with Service {}

{
    local $@;
    eval q[class ConstructorInjection with WithClass, WithParameters, WithDependencies {}];
    is($@, "", '... this worked');
}

done_testing;
