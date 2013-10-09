package BB::Service;
use strict;
use warnings;

use mop;

role WithClass {
    method method { "calling the method method" }
}

no mop;

1;
