package Flack;
use v5.16;
use warnings;
use mop;

class Component is abstract {

    method call;

    method to_app_auto is overload('&{}') { return }

    method prepare_app { return }

    method to_app { return }

    method response_cb ($res, $cb) { return }
}

1;