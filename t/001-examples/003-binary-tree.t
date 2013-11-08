#!perl

use strict;
use warnings;

use Test::More;

use mop;

class BinaryTree {
    has $!node   is rw;
    has $!parent is ro, weak_ref;
    has $!left;
    has $!right;

    method has_parent { defined $!parent }

    method left     { $!left //= ref($self)->new( parent => $self ) }
    method has_left { defined $!left }

    method right     { $!right //= ref($self)->new( parent => $self ) }
    method has_right { defined $!right }
}

my $parent_attr = mop::meta('BinaryTree')->get_attribute('$!parent');

{
    my $t = BinaryTree->new;
    ok($t->isa('BinaryTree'), '... this is a BinaryTree object');

    ok(!$t->has_parent, '... this tree has no parent');

    ok(!$t->has_left, '... left node has not been created yet');
    ok(!$t->has_right, '... right node has not been created yet');

    ok($t->left->isa('BinaryTree'), '... left is a BinaryTree object');
    ok($t->right->isa('BinaryTree'), '... right is a BinaryTree object');

    ok($t->has_left, '... left node has now been created');
    ok($t->has_right, '... right node has now been created');

    ok($t->left->has_parent, '... left has a parent');
    is($t->left->parent, $t, '... and it is us');

    ok($parent_attr->is_data_in_slot_weak_for($t->left), '... the value is weakened');

    ok($t->right->has_parent, '... right has a parent');
    is($t->right->parent, $t, '... and it is us');

    ok($parent_attr->is_data_in_slot_weak_for($t->right), '... the value is weakened');
}

class MyBinaryTree extends BinaryTree {}

{
    my $t = MyBinaryTree->new;
    ok($t->isa('MyBinaryTree'), '... this is a MyBinaryTree object');
    ok($t->isa('BinaryTree'), '... this is a BinaryTree object');

    ok(!$t->has_parent, '... this tree has no parent');

    ok(!$t->has_left, '... left node has not been created yet');
    ok(!$t->has_right, '... right node has not been created yet');

    ok($t->left->isa('BinaryTree'), '... left is a BinaryTree object');
    ok($t->right->isa('BinaryTree'), '... right is a BinaryTree object');

    ok($t->has_left, '... left node has now been created');
    ok($t->has_right, '... right node has now been created');
}

done_testing;
