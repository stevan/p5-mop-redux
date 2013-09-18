#!/usr/bin/env perl
use strict;
use warnings;
use 5.014;

use Benchmark 'cmpthese';
use mop;

package Foo::Moose {
    use Moose;
    has foo => (is => 'rw', isa => 'Str', default => 1);
    has bar => (is => 'rw', default => 1);
}

package Foo::MooseImmutable {
    use Moose;
    has foo => (is => 'rw', isa => 'Str', default => 1);
    has bar => (is => 'rw', default => 1);
    __PACKAGE__->meta->make_immutable;
}

sub type {
    my ($attr, $type_name) = @_;
    my $type = Moose::Util::TypeConstraints::find_type_constraint( $type_name );
    $attr->bind('before:STORE_DATA' => sub { $type->assert_valid( ${ $_[2] } ) });
}

class Foo::MOP {
    has $!foo is type('Str'), rw = 1;
    has $!bar is rw = 1;
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
            my $tc = Moose::Util::TypeConstraints::find_type_constraint('Str');
            $tc->assert_valid($_[0]);
            $self->{foo} = $_[0];
        }
        $self->{foo};
    }
    sub bar {
        my $self = shift;
        $self->{bar} = $_[0] if @_;
        $self->{bar};
    }
}

say "Defaults";
cmpthese(-5, {
    Moose           => sub { Foo::Moose->new          },
    Moose_immutable => sub { Foo::MooseImmutable->new },
    mop             => sub { Foo::MOP->new            },
    raw             => sub { Foo::Raw->new            },
});

say "Constructor params";
cmpthese(-5, {
    Moose           => sub { Foo::Moose->new(foo => 1, bar => 2)          },
    Moose_immutable => sub { Foo::MooseImmutable->new(foo => 1, bar => 2) },
    mop             => sub { Foo::MOP->new(foo => 1, bar => 2)            },
    raw             => sub { Foo::Raw->new(foo => 1, bar => 2)            },
});
