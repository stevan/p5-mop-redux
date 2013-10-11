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
isa_ok($app, 'My::Component');

is($app->call, 'HELLO WORLD', '... got the value we expected');
is($app->bar, 'BAR');

{
    package My::DBI;
    BEGIN { $INC{'My/DBI.pm'} = __FILE__ }
    use strict;
    use warnings;

    sub connect {
        my $class = shift;
        my ($dsn) = @_;
        bless { dsn => $dsn } => $class;
    }

    sub dsn { shift->{dsn} }
}

class My::DBI::MOP extends My::DBI is extending_non_mop('connect') {
    has $!foo;
    has $!bar is ro = "BAR";

    method BUILD (@args) {
        $!foo = 'WORLD';
    }

    method call { "HELLO " . $!foo }
}

my $dbh = My::DBI::MOP->connect('dbi:hash');
isa_ok($dbh, 'My::DBI::MOP');
isa_ok($dbh, 'My::DBI');

is($dbh->call, 'HELLO WORLD', '... got the value we expected');
is($dbh->bar, 'BAR');
is($dbh->dsn, 'dbi:hash');

done_testing;
