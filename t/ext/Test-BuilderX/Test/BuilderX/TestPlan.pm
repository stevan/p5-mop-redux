use strict;
use warnings;
use mop;

class Test::BuilderX::TestPlan {
    has $!expect;

    method BUILD {
        die "Invalid or missing plan" unless defined $!expect;
    }

    method header { "1..$!expect" }

    method footer ( $run ) {
        return '' if $run == $!expect;
        return "Expected $!expect but ran $run";
    }
}

class Test::BuilderX::NullPlan {
    method header { '' }
    method footer ( $run ) { "1..$run" }
}

1;
