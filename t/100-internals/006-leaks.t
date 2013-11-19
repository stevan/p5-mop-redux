#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Scalar::Util 'weaken';

use mop;

package Bar {
    BEGIN { $INC{'Bar.pm'} = __FILE__ }
    sub new { bless {}, shift }
}
class Foo extends Bar is extending_non_mop, repr('HASH'), abstract {
    has $!ro       is ro;
    has $!rw       is rw;
    has $!required is required;
    has $!weak_ref is weak_ref;
    has $!lazy     is lazy;

    method overload is overload('""') { "foo" }
}

{
    weaken(my $meta = mop::meta('Foo'));
    weaken(my $ro_attr = $meta->get_attribute('$!ro'));
    weaken(my $rw_attr = $meta->get_attribute('$!rw'));
    weaken(my $required_attr = $meta->get_attribute('$!required'));
    weaken(my $weak_ref_attr = $meta->get_attribute('$!weak_ref'));
    weaken(my $lazy_attr = $meta->get_attribute('$!lazy'));
    weaken(my $overload_method = $meta->get_method('overload'));
    ok($meta);
    ok($ro_attr);
    ok($rw_attr);
    ok($required_attr);
    ok($weak_ref_attr);
    ok($lazy_attr);
    ok($overload_method);
    mop::remove_meta('Foo');
    ok(!$meta);
    ok(!$ro_attr);
    ok(!$rw_attr);
    ok(!$required_attr);
    ok(!$weak_ref_attr);
    ok(!$lazy_attr);
    ok(!$overload_method);
}

done_testing;
