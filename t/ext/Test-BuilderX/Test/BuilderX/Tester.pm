package Test::BuilderX::Tester;

use strict;
use warnings;
use mop;

use Test::BuilderX;
use Test::BuilderX::Output;

sub import {
    my $to   = caller;
    my $from = shift;
    {
        no strict 'refs';
        map {
            *{"${to}::${_}"} = \&{"${from}::${_}"};
        } qw[
            test_plan
            test_pass
            test_fail
            test_out
            test_err
            test_diag
            test_test
        ];
    }
}


class MockOutput {
    has $!output      = [];
    has $!diagnostics = [];

    method write ( $message ) {
        push @{$!output} => $message;
    }

    method diag ( $message ) {
        push @{$!diagnostics} => $message;
    }

    method output {
        return '' unless @{$!output};
        my $result = join "\n" => @{$!output};
        $!output = [];
        return $result;
    }

    method diagnostics {
        return '' unless @{$!diagnostics};
        my $result = join "\n" => @{$!diagnostics};
        $!diagnostics = [];
        return $result;
    }
}

my @expect_out;
my @expect_diag;

my $Test           = Test::BuilderX->new;
my $TB_Test_Output = Test::BuilderX::Tester::MockOutput->new;
my $TB_Test        = Test::BuilderX->new( output => $TB_Test_Output );

$TB_Test->plan( 'no_plan' );
$TB_Test_Output->output; # flush this

sub test_plan {
    my ($tests) = @_;
    $Test->plan( tests => $tests );
}

sub test_pass {
    my ($diagnostic) = @_;
    report_test( 'ok', $diagnostic );
}

sub test_fail {
    my ($diagnostic) = @_;
    report_test( 'not ok', $diagnostic );
}

sub report_test {
    my ($type, $diagnostic) = @_;
    my $number = $TB_Test->get_test_number;
    my $line   = "$type $number";
    $line .= " - $diagnostic" if defined $diagnostic;
    test_out( $line );
}

sub test_out {
    my ($line) = @_;
    push @expect_out => $line;
}

sub test_err {
    my ($line) = @_;
    push @expect_diag => $line;
}

sub test_diag {
    my ($line) = @_;
    push @expect_diag => $line;
}

sub test_test {
    my ($description) = @_;

    my $expect_out  = join "\n" => @expect_out;
    my $expect_diag = join "\n" => @expect_diag;
    @expect_out     = ();
    @expect_diag    = ();

    my $received_out  = $TB_Test_Output->output;
    my $received_diag = $TB_Test_Output->diagnostics;

    my $out_matches   = $expect_out  eq $received_out;
    my $diag_matches  = $expect_diag eq $received_diag;

    return 1 if $Test->ok( ($out_matches && $diag_matches), $description );

    $Test->diag(
        "output mismatch\nexpected: $expect_out\nreceived: $received_out\n"
    ) unless $out_matches;

    $Test->diag(
        "diagnostics mismatch\n" .
        "expected: '$expect_diag'\nreceived: '$received_diag'\n"
    ) unless $diag_matches;

    return 0;
}

1;