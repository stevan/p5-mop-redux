#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Point {
    has $x;
    has $y;

    method x { $x }
    method y { $y }

    method set_x ($new_x) {
        $x = $new_x;
    }

    method set_y ($new_y) {
        $y = $new_y;
    }

    method clear {
        ($x, $y) = (0, 0);
    }

    method dump {
        +{ x => $self->x, y => $self->y }
    }
}

# ... subclass it ...

class Point3D (extends => 'Point') {
    has $z;

    method z { $z }

    method set_z ($new_z) {
        $z = $new_z;
    }

    method dump {
        +{ x => $self->x, y => $self->y, z => $self->z }
    }
}
 
## Test an instance

my $p = Point->new;
isa_ok($p, 'Point');

$p->set_x(10);
is $p->x, 10, '... got the right value for x';

$p->set_y(320);
is $p->y, 320, '... got the right value for y';

is_deeply $p->dump, { x => 10, y => 320 }, '... got the right value from dump';

## Test the instance

my $p3d = Point3D->new();
isa_ok($p3d, 'Point3D');

$p3d->set_x(10);
is $p3d->x, 10, '... got the right value for x';

$p3d->set_y(320);
is $p3d->y, 320, '... got the right value for y';

$p3d->set_z(30);
is $p3d->z, 30, '... got the right value for z';

is_deeply $p3d->dump, { x => 10, y => 320, z => 30 }, '... got the right value from dump';

done_testing;



