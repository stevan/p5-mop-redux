use strict;
use warnings;
use Test::More;

eval 'use Test::NoTabs';
if ($@) {
    $ENV{RELEASE_TESTING} ? die : plan skip_all => 'Test::NoTabs required';
}

all_perl_files_ok();
