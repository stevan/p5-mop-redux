use strict;
use warnings;
use Test::More;

use twigils;

my %skip = (map {
    ($_ => 1)
} ' ', '#', '$', '[', '{', "'", 0 .. 9, 'a' .. 'z');

for my $kind (qw(my state our)) {
    for my $c (map { chr } 32 .. 127) {
        next if $skip{$c};

        my $code = qq{
            intro_twigil_${kind}_var \$${c}foo;
            \$${c}foo = 42;
            ::is \$${c}foo, 42;
        };

        {
            no warnings 'syntax', 'deprecated';
            eval $code;
        }

        if ($@) {
            fail $c;
            diag "$c $@";
        }
    }
}

done_testing;
