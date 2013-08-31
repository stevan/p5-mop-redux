package Flack::Middleware;
use v5.16;
use warnings;
use mop;

class AccessLog extends Flack::Middleware is overload('inherited') {
    has $!logger is rw;
    has $!format is rw;
    has $!compiled_format is rw;

    method call ($env) {
        # ...
    }

}

1;