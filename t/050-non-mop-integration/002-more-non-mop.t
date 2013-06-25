#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use Data::Dumper 'Dumper';

use mop;
use mop::util qw[ find_meta ];

{
    package Person;
    use Moose;

    # NOTE:
    # we have to make these attribute lazy 
    # because of how Moose does constructors
    # that are inherited by non-Moose classes
    # - SL

    has 'first_name' => (is => 'rw', default => 'stevan', lazy => 1);
    has 'last_name'  => (is => 'rw', default => 'little', lazy => 1);

    __PACKAGE__->meta->make_immutable;
}

class Employee (extends => 'Person') {
    has $manager;

    method manager ($m) { 
        $manager = $m if $m;
        $manager;
    }
}

#warn Dumper find_meta('Employee');

my $e = Employee->new;
isa_ok($e, 'Employee');
#isa_ok($e, 'Person');

can_ok($e, 'first_name');
can_ok($e, 'last_name');
can_ok($e, 'manager');

is($e->first_name, 'stevan', '... got the expected default value');
is($e->last_name, 'little', '... got the expected default value');

my $m = Employee->new( first_name => 'pointy', last_name => 'hairedboss' );

$e->manager($m);
is_deeply($e->manager, $m, '... got the expected manager');

#warn Dumper $e;
#warn Dumper find_meta('Employee');

is_deeply(
    mop::mro::get_linear_isa('Employee'),
    [ 'Employee', 'Person', 'Moose::Object' ],
    '... got the expected linear isa'
);

done_testing;