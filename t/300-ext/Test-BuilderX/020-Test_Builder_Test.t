#!perl

use strict;
use warnings;

use Test::More;
use lib 't/ext/Test-BuilderX';

BEGIN {
    use_ok( 'Test::BuilderX::Test' );
}

my $pass_test = Test::BuilderX::Test->new(
    number      => 1,
    passed      => 1,
    description => 'first test description'
);
ok( $pass_test->isa( 'Test::BuilderX::Test::Pass' ), '... we got a Test::BuilderX::Test::Pass instance');
is($pass_test->number, 1, '... got the right test number');
ok($pass_test->passed, '... this test passed');
is($pass_test->description, 'first test description', '... got the right test description');
is_deeply( $pass_test->status, { passed => 1, description => 'first test description' }, '... got the right status');
is($pass_test->report, 'ok 1 - first test description', '... got the right report');

my $fail_test = Test::BuilderX::Test->new(
    number      => 2,
    passed      => 0,
    description => 'first test description'
);
ok( $fail_test->isa('Test::BuilderX::Test::Fail'), '... we got a Test::BuilderX::Test::Fail instance');
is($fail_test->number, 2, '... got the right test number');
ok(!$fail_test->passed, '... this test passed');
is($fail_test->description, 'first test description', '... got the right test description');
is_deeply( $fail_test->status, { passed => 0, description => 'first test description' }, '... got the right status');
is($fail_test->report, 'not ok 2 - first test description', '... got the right report');

my $todo_test = Test::BuilderX::Test->new(
    number      => 3,
    passed      => 1,
    description => 'first test description',
    todo        => 1,
    reason      => 'this is TODO',
);
ok( $todo_test->isa('Test::BuilderX::Test::TODO'), '... we got a Test::BuilderX::Test::TODO instance');
is($todo_test->number, 3, '... got the right test number');
ok($todo_test->passed, '... this test passed');
is($todo_test->description, 'first test description', '... got the right test description');
is_deeply(
    $todo_test->status,
    {
        passed        => 1,
        really_passed => 1,
        reason        => 'this is TODO',
        description   => 'first test description',
        TODO          => 1
    },
    '... got the right status'
);
is($todo_test->report, 'ok 3 # TODO first test description', '... got the right report');

my $skip_test = Test::BuilderX::Test->new(
    number      => 4,
    passed      => 1,
    description => 'first test description',
    skip        => 1,
    reason      => 'this is Skip',
);
ok( $skip_test->isa('Test::BuilderX::Test::Skip'), '... we got a Test::BuilderX::Test::Skip instance');
is($skip_test->number, 4, '... got the right test number');
ok($skip_test->passed, '... this test passed');
is($skip_test->description, 'first test description', '... got the right test description');
is_deeply(
    $skip_test->status,
    {
        passed      => 1,
        skip        => 1,
        reason      => 'this is Skip',
        description => 'first test description',
    },
    '... got the right status'
);
is($skip_test->report, 'not ok 4 #skip this is Skip', '... got the right report');



done_testing;


