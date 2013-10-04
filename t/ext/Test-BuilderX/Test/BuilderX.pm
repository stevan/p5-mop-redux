use strict;
use warnings;
use mop;

use Test::BuilderX::Test;
use Test::BuilderX::Output;
use Test::BuilderX::TestPlan;

class Test::BuilderX {

    has $!output;
    has $!testplan;
    has $!results = [];

    method BUILD {
        $!output //= Test::BuilderX::Output->new;
    }

    method DEMOLISH {
        return unless $!testplan;
        my $footer = $!testplan->footer( scalar @{$!results} );
        $!output->write( $footer ) if $footer;
    }

    method get_test_number { (scalar @{$!results}) + 1 }

    method plan ( $explanation, $tests ) {
        die "Plan already set" if $!testplan;

        if ( $tests ) {
            $!testplan = Test::BuilderX::TestPlan->new( expect => $tests );
        }
        elsif ( $explanation eq 'no_plan' ) {
            $!testplan = Test::BuilderX::NullPlan->new;
        }
        else {
            die "Unknown plan";
        }

        $!output->write( $!testplan->header );
    }

    method ok ( $passed, $description ) {
        $self->report_test(
            Test::BuilderX::Test->new(
                number      => $self->get_test_number,
                passed      => $passed,
                description => $description // ''
            )
        );

        return $passed;
    }

    method diag ( $diagnostic ) {
        $!output->diag( $diagnostic // '' );
    }

    method todo ( $passed, $description, $reason ) {
        $self->report_test(
            Test::BuilderX::Test->new(
                todo        => 1,
                number      => $self->get_test_number,
                reason      => $reason,
                description => $description // ''
            )
        );

        return $passed;
    }

    method skip ( $num, $reason ) {
        for ( 1 .. $num ) {
            $self->report_test(
                Test::BuilderX::Test->new(
                    skip        => 1,
                    number      => $self->get_test_number,
                    reason      => $reason,
                )
            );
        }
    }

    method skip_all {
        die "Cannot skip_all with a plan" if $!testplan;
        $!output->write( "1..0" );
        exit(0);
    }

    method BAILOUT ( $reason ) {
        $!output->write( "Bail out! $reason" );
        exit(255);
    }

    method report_test ( $test ) {
        die "No plan set!" unless $!testplan;

        push @{$!results} => $test;
        $!output->write( $test->report );
    }
}

1;







