#!perl

use strict;
use warnings;

use Test::More;

use mop;

class LinkedList {
    has $!head  is ro;
    has $!tail  is ro;
    has $!count is ro = 0;

    method append ($node) {
        unless($!tail) {
            $!tail = $node;
            $!head = $node;
            $!count++;
            return;
        }
        $!tail->set_next($node);
        $node->set_previous($!tail);
        $!tail = $node;
        $!count++;
    }

    method insert ($index, $node) {
        die "Index ($index) out of bounds"
            if $index < 0 or $index > $!count - 1;

        my $tmp = $!head;
        $tmp = $tmp->get_next while($index--);
        $node->set_previous($tmp->get_previous);
        $node->set_next($tmp);
        $tmp->get_previous->set_next($node);
        $tmp->set_previous($node);
        $!count++;
    }

    method remove ($index) {
        die "Index ($index) out of bounds"
            if $index < 0 or $index > $!count - 1;

        my $tmp = $!head;
        $tmp = $tmp->get_next while($index--);
        $tmp->get_previous->set_next($tmp->get_next);
        $tmp->get_next->set_previous($tmp->get_previous);
        $!count--;
        $tmp->detach();
    }

    method prepend ($node) {
        unless($!head) {
            $!tail = $node;
            $!head = $node;
            $!count++;
            return;
        }
        $!head->set_previous($node);
        $node->set_next($!head);
        $!head = $node;
        $!count++;
    }

    method sum {
        my $sum = 0;
        my $tmp = $!head;
        do { $sum += $tmp->get_value } while($tmp = $tmp->get_next);
        return $sum;
    }
}

class LinkedListNode {
    has $!previous;
    has $!next;
    has $!value;

    method get_previous { $!previous }
    method get_next { $!next }
    method get_value { $!value }
    method set_previous($x) { $!previous = $x; }
    method set_next($x) { $!next = $x; }
    method set_value($x) { $!value = $x; }

    method detach { ($!previous, $!next) = (undef) x 2; $self }
}

{
    my $ll = LinkedList->new();

    for(0..9) {
        $ll->append(
            LinkedListNode->new(value => $_)
        );
    }

    is($ll->head->get_value, 0, '... head is 0');
    is($ll->tail->get_value, 9, '... tail is 9');
    is($ll->count, 10, '... count is 10');

    $ll->prepend(LinkedListNode->new(value => -1));
    is($ll->count, 11, '... count is now 11');

    $ll->insert(5, LinkedListNode->new(value => 11));
    is($ll->count, 12, '... count is now 12');

    my $node = $ll->remove(8);
    is($ll->count, 11, '... count is 11 again');

    ok(!$node->get_next, '... detached node does not have a next');
    ok(!$node->get_previous, '... detached node does not have a previous');
    is($node->get_value, 6, '... detached node has the right value');
    ok($node->isa('LinkedListNode'), '... node is a LinkedListNode');

    eval { $ll->remove(99) };
    like($@, qr/^Index \(99\) out of bounds/, '... removing out of range produced error');
    eval { $ll->insert(-1, LinkedListNode->new(value => 2)) };
    like($@, qr/^Index \(-1\) out of bounds/, '... inserting out of range produced error');

    is($ll->sum, 49, '... things sum correctly');
}

done_testing;
