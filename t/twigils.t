use strict;
use warnings;
use Test::More;

use twigils;

my %skip = (map {
    ($_ => 1)
} ' ', '#', '$');

for my $c (map { chr } 32 .. 127) {
    next if $skip{$c};

    my $code = qq{
        twigils::intro_twigil_var('\$${c}foo');
        \$${c}foo = 42;
        ::is \$${c}foo, 42;
    };

    eval $code;
    if ($@) {
        fail $c;
        diag "$c $@";
    }
}

done_testing;
