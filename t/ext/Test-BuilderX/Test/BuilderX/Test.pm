package Test::BuilderX::Test;
use strict;
use warnings;
use mop;

sub new {
    shift;
    my %params = @_;
    my ($number, $passed, $skip, $todo, $reason, $description) = @params{qw[
        number
        passed
        skip
        todo
        reason
        description
    ]};

    return Test::BuilderX::Test::TODO->new(
        description => $description,
        passed      => $passed,
        reason      => $reason,
        number      => $number,
    ) if $todo;

    return Test::BuilderX::Test::Skip->new(
        description => $description,
        passed      => 1,
        reason      => $reason,
        number      => $number,
    ) if $skip;

    return Test::BuilderX::Test::Pass->new(
        description => $description,
        passed      => 1,
        number      => $number,
    ) if $passed;

    return Test::BuilderX::Test::Fail->new(
        description => $description,
        passed      => 0,
        number      => $number,
    );
}

class Base {

    has $!passed      is ro;
    has $!description is ro;
    has $!number      is ro = 0;
    has $!diagnostic        = '???';

    method status {
        return +{ passed => $!passed, description => $!description }
    }

    method report {
        my $ok = $!passed ? 'ok ' : 'not ok ';
        $ok .= $!number;
        $ok .= " - $!description" if $!description;
        return $ok;
    }
}

class Pass extends Test::BuilderX::Test::Base {}
class Fail extends Test::BuilderX::Test::Base {}

class WithReason extends Test::BuilderX::Test::Base {
    has $!reason is ro;

    method status {
        my $status = $self->next::method;
        $status->{'reason'} = $!reason;
        $status;
    }
}

class Skip extends Test::BuilderX::Test::WithReason {

    method report {
        return "not ok " . $self->number . " #skip " . $self->reason;
    }

    method status {
        my $status = $self->next::method;
        $status->{'skip'} = 1;
        $status;
    }
}

class TODO extends Test::BuilderX::Test::WithReason {

    method report {
        my $ok          = $self->passed ? 'ok' : 'not ok';
        my $description = "# TODO " . $self->description;
        return join ' ' => ( $ok, $self->number, $description );
    }

    method status {
        my $status = $self->next::method;
        $status->{'TODO'}          = 1;
        $status->{'passed'}        = 1;
        $status->{'really_passed'} = $self->passed;
        $status;
    }
}

1;

