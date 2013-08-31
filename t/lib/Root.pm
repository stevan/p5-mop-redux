use strict;
use warnings;
use mop;
class Root {
    has $!foo;

    method foo () { $!foo }
}

1;