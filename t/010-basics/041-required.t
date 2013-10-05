#!perl

use strict;
use warnings;

use Test::More;

use mop;

class Foo {
    has $!foo = 'DFOO';
    has $!bar is required;

    method foo { $!foo }
    method bar { $!bar }
}

{
    my $foo = Foo->new(foo => 'FOO', bar => 'BAR');
    is($foo->foo, 'FOO', 'attribute with default and arg');
    is($foo->bar, 'BAR', 'required attribute with arg');
}

{
    my $foo = Foo->new(bar => 'BAR');
    is($foo->foo, 'DFOO', 'attribute with default and no arg');
    is($foo->bar, 'BAR', 'required attribute with arg');
}

eval { Foo->new };
like( $@,
      qr/^'\$!bar' is required/,
      'missing required attribute throws an exception'
);

eval 'class Bar { has $!baz is required = "DBAZ" })';
like $@,  qr/in '\$!baz' attribute definition: 'required' trait is incompatible with default value/;

done_testing;
