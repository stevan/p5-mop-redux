#!perl

use v5.16;
use strict;
use warnings;

use Test::More;

use mop;

{
    package My::Component;
    BEGIN { $INC{'My/Component.pm'} = __FILE__ }
    use strict;
    use warnings;

    sub new {
        my $class = shift;
        bless { @_ } => $class;
    }
}

class App extends My::Component is extending_non_mop {
    has $!foo;
    has $!bar is ro = "BAR";

    method BUILD (%args) {
        $!foo = $args{'foo'};
    }

    method call { "HELLO " . $!foo }
}

my $app = App->new( foo => 'WORLD' );
isa_ok($app, 'App');

is($app->call, 'HELLO WORLD', '... got the value we expected');

is($app->bar, 'BAR');

done_testing;
