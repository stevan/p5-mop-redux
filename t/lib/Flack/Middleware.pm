package Flack;
use v5.16;
use warnings;
use mop;

class Middleware extends Flack::Component is abstract {
    has $!app is rw;

    method wrap ($app, @args) {
        return
    }
}

1;