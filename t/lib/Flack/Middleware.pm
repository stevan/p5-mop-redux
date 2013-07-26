package Flack;
use v5.16;
use warnings;
use mop;

class Middleware extends Flack::Component is overload('inherited'), abstract {
    has $app is rw;

    method wrap ($_app, @args) {
        return
    }
}

1;