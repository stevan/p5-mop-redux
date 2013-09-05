package main;
use strict;
use warnings;

use mop;

use Circular::Child;

class Circular {
    method child { Circular::Child->new }
}

1;
