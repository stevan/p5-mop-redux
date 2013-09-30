#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

role R1 { method foo { 1 } }
role R2 { method foo { 1 } }
role R3 { method foo { 1 } }
role R4 { method foo { 1 } }
role R5 { method foo { 1 } }

eval "class C1 with R1 { }";
is($@, '');

eval "class C2 with R1, R2 { }";
like($@, qr/Required method\(s\) \[foo\] are not allowed in C2 unless class is declared abstract/);

eval "class C3 with R1, R2, R3 { }";
like($@, qr/Required method\(s\) \[foo\] are not allowed in C3 unless class is declared abstract/);

eval "class C4 with R1, R2, R3, R4 { }";
like($@, qr/Required method\(s\) \[foo\] are not allowed in C4 unless class is declared abstract/);

eval "class C5 with R1, R2, R3, R4, R5 { }";
like($@, qr/Required method\(s\) \[foo\] are not allowed in C5 unless class is declared abstract/);

role R1_required { method foo; }

eval "class C1_required with R1_required, R2 { }";
is($@, '');

done_testing;
