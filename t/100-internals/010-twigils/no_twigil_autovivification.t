use strict;
use warnings;
use Test::More;
use Test::Fatal;

{
    use twigils allowed_twigils => '!', 'fatal_lookup_errors';

    eval 'intro_twigil_my_var $.foo';
    like $@, qr/^Unregistered sigil character \./;
}

done_testing;
