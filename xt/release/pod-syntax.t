#!perl
use Test::More;

eval "use Test::Pod 1.41";
if ($@) {
    $ENV{RELEASE_TESTING} ? die : plan skip_all => 'Test::Pod 1.41 required';
}

all_pod_files_ok();
