#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

role R1 {
    method foo { 'R1' }
}

role R2 {
    method foo { 'R2' }
}

class C1 { }
my $C1 = mop::meta('C1');

ok(!C1->can('foo'));

$C1->add_role('R1');
$C1->FINALIZE;

ok(C1->can('foo'));
is(C1->new->foo, 'R1');

$C1->add_role('R2');
eval {
    $C1->FINALIZE;
};
like($@, qr/^Required method\(s\) \[foo\] are not allowed in C1 unless class is declared abstract/);

$C1->add_method(mop::method->new(name => 'foo', body => sub { 'C1' }));
$C1->FINALIZE;

ok(C1->can('foo'));
is(C1->new->foo, 'C1');

role R3 {
    has $!foo = 'R3';
}

role R4 {
    has $!foo = 'R4';
}

class C2 { }
my $C2 = mop::meta('C2');

$C2->add_role('R3');
$C2->FINALIZE;
$C2->add_role('R4');
eval {
    $C2->FINALIZE;
};
like($@, qr/^Attribute conflict \$!foo when composing/);

class C3 {
    method foo { 'C3' }
}
my $C3 = mop::meta('C3');

is(C3->new->foo, 'C3');

$C3->add_role('R1');
$C3->FINALIZE;

is(C3->new->foo, 'C3');

$C3->add_role('R2');
$C3->FINALIZE;

is(C3->new->foo, 'C3');

class C4 is abstract {
    method bar;
}
my $C4 = mop::meta('C4');

eval '
class C5 extends C4 { }
';
like($@, qr/^Required method\(s\) \[bar\] are not allowed in C5 unless class is declared abstract/);

$C4->add_role('R1');
$C4->FINALIZE;
can_ok('C4', 'foo');
is(C4->foo, 'R1');

eval '
class C6 extends C4 { }
';
{ local $TODO = "we don't track the source of required methods yet";
like($@, qr/^Required method\(s\) \[bar\] are not allowed in C6 unless class is declared abstract/);
}

done_testing;
