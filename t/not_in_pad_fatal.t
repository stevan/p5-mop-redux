use strict;
use warnings;
use Test::More;
use Test::Fatal;

{
    use twigils;

    intro_twigil_my_var $!foo;

    eval 'no warnings; warn $!bar';
    like $@, qr/^Missing comma after first argument to warn function/;
}

{
    use twigils 'fatal_lookup_errors';

    intro_twigil_my_var $!foo;

    eval 'warn $!bar';
    like $@, qr/^Not such twigil variable \$!bar/;
}

done_testing;
