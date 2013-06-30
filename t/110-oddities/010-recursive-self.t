#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use mop;

my @lexical;
my @global;

class Tree {
    has $node;
    has $parent;
    has $children = [];

    method node   { $node   }
    method parent { $parent }
    method _set_parent ($p) { $parent = $p }

    method children { $children }

    method add_child ( $t ) {
        $t->_set_parent( $self );
        push @$children => $t;
        $self;
    }

    method traverse ($indent) {
       $indent ||= '';
       push @lexical, $self;
       push @global, ${^SELF};
       foreach my $t ( @$children ) {
           # warn $t, ' => ', $t->node;
           $t->traverse( $indent . '  ' );
       }
    }
}


my $t = Tree->new( node => '0.0' )
            ->add_child( Tree->new( node => '1.0' ) )
            ->add_child(
                Tree->new( node => '2.0' )
                    ->add_child( Tree->new( node => '2.1' ) )
            )
            ->add_child( Tree->new( node => '3.0' ) )
            ->add_child( Tree->new( node => '4.0' ) );

$t->traverse;
is_deeply(\@lexical, \@global, '... we do not suffer the same fate as the old prototype');

done_testing;
