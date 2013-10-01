use strict;
use warnings;
use Test::More;

eval 'use Test::EOL';
if ($@) {
    $ENV{RELEASE_TESTING} ? die : plan skip_all => 'Test::EOL required';
}

all_perl_files_ok({ trailing_whitespace => 1 });
