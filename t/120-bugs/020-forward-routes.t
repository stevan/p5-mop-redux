#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use lib 't/lib';

use Backward::Routes;

{
    local $TODO = 'doy needs to fix his metaclass compat stuff';
    my $a = Backward::Routes->new;
    is(exception { $a->add_resource }, undef, '... this does not die');
}

done_testing;