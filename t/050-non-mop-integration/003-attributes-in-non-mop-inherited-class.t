#!perl

use v5.16;
use strict;
use warnings;

use Test::More;
use Test::Fatal;

use mop;

{
    package My::Component;
    use strict;
    use warnings;

    sub new { 
        my $class = shift; 
        bless { @_ } => $class;
    }
}

class App extends My::Component is extending_non_mop {
    has $foo;

    submethod BUILD (%args) {
        $foo = $args{'foo'};
    }

    method call { "HELLO " . $foo }
}

my $app = App->new( foo => 'WORLD' );
isa_ok($app, 'App');

is($app->call, 'HELLO WORLD', '... got the value we expected');

done_testing;