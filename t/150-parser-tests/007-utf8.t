#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

# the real parser is going to need to have this test pass
BEGIN {
    plan skip_all => "Parse::Keyword doesn't handle unicode"
        if $INC{'Parse/Keyword.pm'};
}

use utf8;

class Föo {
    has $!Àbc is ro = "café";

    method þing { "NO THORNS" }
}

my $Föo = mop::meta('Föo');
is($Föo->name, 'Föo');

my $Àbc = $Föo->get_attribute('$!Àbc');
is($Àbc->name, 'Àbc');
is($Àbc->get_default, 'café');

my $þing = $Föo->get_method('þing');
is($þing->name, 'þing');

my $föo = Föo->new;
is($föo->Àbc, 'café');
is($föo->þing, 'NO THORNS');

done_testing;
