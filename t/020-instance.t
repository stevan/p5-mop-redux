#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

{
    package Foo;
    use strict;
    use warnings;

    use Data::Dumper          qw[ Dumper ];
    use Variable::Magic       qw[ wizard cast ];
    use Hash::Util::FieldHash qw[ fieldhash ];

    fieldhash my %foo;

    my $wiz = wizard(
        data => sub { $_[1] },
        set  => sub { $_[1]->[0]->{ $_[1]->[1] } = $_[0] },
    );

    sub foo {
        my $self = shift;
        my $foo  = $foo{$self};
        cast $foo, $wiz, [ \%foo, $self ]; 

        $foo = shift if @_;
        $foo;
    }

    sub dump {
        warn Dumper \%foo;
    }
}

my $foo = bless \(my $x) => 'Foo';

$foo->foo;
$foo->dump;

$foo->foo(10);
$foo->dump;

$foo->foo([ 2, 3, 4 ]);
$foo->dump;

done_testing;