use strict;
use warnings;
use Test::More;
use Test::Fatal;

use twigils;

{
    intro_twigil_my_var @!foo;
    intro_twigil_my_var @.bar;

    @!=(123, 456);
    is_deeply \@!, [123, 456];
    @.=(123, 456);
    is_deeply\@., [123, 456];

    @!foo = (1, 2);
    @.bar = (2, 3);

    is_deeply \@!foo, [1, 2];
    is_deeply \@.bar, [2, 3];

    TODO: {
        local $TODO = 'array interpolation';
        is "@!foo", "1 2 2 3";
    }

    eval 'no warnings; warn @!bar';
    like $@, qr/^syntax error/;
}

{
    intro_twigil_my_var @.eq;

    @.eq = (42);
    is_deeply \@.eq, [42];
    is @. eq@.eq, '';
}

{
    for (1 .. 2) {
        intro_twigil_my_var @!foo;
        is_deeply \@!foo, [];
        @!foo = ($_);
        is_deeply \@!foo, [$_];
    }

    eval 'no warnings; warn @!foo';
    like $@, qr/^syntax error/;
}

{
    for (1 .. 2) {
        intro_twigil_state_var @!foo;
        is_deeply \@!foo, $_ == 1 ? [] : [1];
        @!foo = ($_);
        is_deeply \@!foo, [$_];
    }

    eval 'no warnings; warn @!foo';
    like $@, qr/^syntax error/;
}

{
    {
        my @x = (3);
        no strict 'refs';
        *{'@!moo'} = \@x;
    }

    for (1 .. 2) {
        intro_twigil_our_var @!moo;
        is_deeply \@!moo, $_ == 1 ? [3] : [1];
        @!moo = ($_);
        is_deeply \@!moo, [$_];
    }

    is_deeply [do {
        no strict 'refs';
        @{ *{'@!moo'}{ARRAY} }
    }], [2];

    eval 'no warnings; warn @!moo';
    like $@, qr/^syntax error/;
}

{
    eval 'no warnings; warn @!foo';
    like $@, qr/^syntax error/;

    eval 'twigils::intro_twigil_my_var($foo)';
    like $@, qr/^Unable to extract compile time constant twigil variable name/;

    eval 'intro_twigil_my_var \'@foo\'';
    like $@, qr/^syntax error/;

    like exception {
        &intro_twigil_my_var('foo');
    }, qr/called as a function/;
}

{
    @!=(123, 456);
    is_deeply \@!, [123, 456];
    @.=(123, 456);
    is_deeply\@., [123, 456];
}

done_testing;
