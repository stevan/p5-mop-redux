#!/usr/bin/env perl
use strict;
use warnings;
use 5.014;

use Benchmark 'cmpthese';
use mop;

package Foo::Moose {
    use Moose;
    has foo => (is => 'rw', default => 1);
    has bar => (is => 'rw', default => 1);
    sub baz { 1 }
}

package Foo::MooseImmutable {
    use Moose;
    has foo => (is => 'rw', default => 1);
    has bar => (is => 'rw', default => 1);
    sub baz { 1 }
    __PACKAGE__->meta->make_immutable;
}

class Foo::MOP {
    has $!foo is rw = 1;
    has $!bar is rw = 1;
    method baz { 1 }
}

package Foo::Raw {
    sub new {
        my $class = shift;
        my %opts = @_;
        bless {
            foo => $opts{foo} // 1,
            bar => $opts{bar} // 1,
        }, $class
    }
    sub foo {
        my $self = shift;
        if (@_) {
            $self->{foo} = $_[0];
        }
        $self->{foo};
    }
    sub bar {
        my $self = shift;
        $self->{bar} = $_[0] if @_;
        $self->{bar};
    }
    sub baz { 1 }
}

my $moose           = Foo::Moose->new;
my $moose_immutable = Foo::MooseImmutable->new;
my $mop             = Foo::MOP->new;
my $raw             = Foo::Raw->new;

say "Plain method:";
cmpthese(-5, {
    Moose           => sub { $moose->baz           },
    Moose_immutable => sub { $moose_immutable->baz },
    mop             => sub { $mop->baz             },
    raw             => sub { $raw->baz             },
});

say "Reader";
cmpthese(-5, {
    Moose           => sub { $moose->bar           },
    Moose_immutable => sub { $moose_immutable->bar },
    mop             => sub { $mop->bar             },
    raw             => sub { $raw->bar             },
});

say "Writer";
cmpthese(-5, {
    Moose           => sub { $moose->bar(2)           },
    Moose_immutable => sub { $moose_immutable->bar(2) },
    mop             => sub { $mop->bar(2)             },
    raw             => sub { $raw->bar(2)             },
});

