use strict;
use warnings;
use Test::More;
use Test::Fatal;

use twigils;

{
    twigils::intro_twigil_my_var('$!foo');
    twigils::intro_twigil_my_var('$.bar');

    $!=123;
    is 0+$!, 123;
    $.=123;
    is$., 123;

    $!foo = 1;
    $.bar = 2;

    is $!foo, 1;
    is $.bar, 2;

    is "$!foo$.bar", 12;

    eval 'warn $!bar';
    like $@, qr/^twigil variable \$!bar not found/;

    $! = 123;
    ok 0+$! eq 123;
    $. = 123;
    ok $. eq 123;
}

{
    for (1 .. 2) {
        twigils::intro_twigil_my_var('$!foo');
        is $!foo, undef;
        $!foo = $_;
        is $!foo, $_;
    }

    eval 'no warnings; warn $!foo';
    like $@, qr/^Missing comma after first argument to warn function/;
}

{
    for (1 .. 2) {
        twigils::intro_twigil_state_var('$!foo');
        is $!foo, $_ == 1 ? undef : 1;
        $!foo = $_;
        is $!foo, $_;
    }

    eval 'no warnings; warn $!foo';
    like $@, qr/^Missing comma after first argument to warn function/;
}

{
    {
        my $x = 3;
        no strict 'refs';
        *{'$!moo'} = \$x;
    }

    for (1 .. 2) {
        twigils::intro_twigil_our_var('$!moo');
        is $!moo, $_ == 1 ? 3 : 1;
        $!moo = $_;
        is $!moo, $_;
    }

    is do {
        no strict 'refs';
        ${ *{'$!moo'}{SCALAR} }
    }, 2;

    eval 'no warnings; warn $!moo';
    like $@, qr/^Missing comma after first argument to warn function/;
}

{
    eval 'no warnings; warn $!foo';
    like $@, qr/^Missing comma after first argument to warn function/;

    eval 'twigils::intro_twigil_my_var($foo)';
    like $@, qr/^Unable to extract compile time constant twigil variable name/;

    like exception {
        &twigils::intro_twigil_my_var('foo');
    }, qr/called as a function/;
}

{
    $! = 123;
    ok 0+$!eq 123;
    $. = 123;
    ok $.eq 123;
}

done_testing;
