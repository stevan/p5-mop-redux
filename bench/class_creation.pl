#!/usr/bin/env perl
use strict;
use warnings;
use 5.014;

use Benchmark 'cmpthese';

my $moose = <<'MOOSE';
package Foo::Moose::Iter%s;
use Moose;
has foo => (is => "ro");
sub bar { }
MOOSE

my $moose_immutable = <<'MOOSE';
package Foo::MooseImmutable::Iter%s;
use Moose;
has foo => (is => "ro");
sub bar { }
__PACKAGE__->meta->make_immutable;
MOOSE

my $mop = <<'MOP';
use mop;
class Foo::MOP::Iter%s {
    has $!foo is ro;
    method bar { }
}
MOP

my $raw = <<'RAW';
package Foo::Raw::Iter%s;
sub new {
    my $class = shift;
    my %%opts = @_;
    bless {
        foo => $opts{foo},
    }, $class;
}
sub foo { $_[0]->{foo} }
sub bar { }
RAW

say "Class creation";
cmpthese(-5, {
    Moose           => sub { eval sprintf $moose,           state($iter)++ },
    Moose_immutable => sub { eval sprintf $moose_immutable, state($iter)++ },
    mop             => sub { eval sprintf $mop,             state($iter)++ },
    raw             => sub { eval sprintf $raw,             state($iter)++ },
});
