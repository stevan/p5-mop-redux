#!/usr/bin/env perl
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use B;

use mop;

class Foo {
    has $!foo = 'Foo::foo';
    has $!bar = 'Foo::bar';

    method foo { $!foo }

    method load_stuff {
        my $foo = $!foo;
        use Baz;
        return $foo . $!foo;
    }

    method bar { $!bar }

    method const { 2 }

    method with_params ($x, $y = time + rand(1) / 256) { 56 }
}

{
    my $foo = Foo->new;
    is($foo->foo, 'Foo::foo');
    is($foo->bar, 'Foo::bar');
    is($foo->load_stuff, 'Foo::fooFoo::foo');
    is($foo->const, 2);
}

{
    my $baz = Baz->new;
    is($baz->bar, 'Baz::bar');
    is($baz->baz, 'Baz::baz');
    is($baz->const, 1);
    is($baz->concat, 'Baz::barBaz::baz');
}

{
    my $Foo = mop::meta('Foo');
    optree_ok($Foo->get_method('foo')->body, '$!foo');
    optree_ok($Foo->get_method('bar')->body, '$!bar');
    optree_ok($Foo->get_method('load_stuff')->body, '$!foo');
    optree_ok($Foo->get_method('const')->body);
    optree_ok($Foo->get_method('with_params')->body);
}

{
    my $Baz = mop::meta('Baz');
    optree_ok($Baz->get_method('bar')->body, '$!bar');
    optree_ok($Baz->get_method('baz')->body, '$!baz');
    optree_ok($Baz->get_method('const')->body);
    optree_ok($Baz->get_method('concat')->body, '$!bar', '$!baz');
}

sub optree_ok {
    my ($body, @attrs) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $cv = B::svref_2object($body);
    die "not a CV!" unless $cv->isa('B::CV');
    die "no CvSTART!" unless $cv->ROOT->isa('B::OP');

    my @initialized;
    {
        no warnings 'once';
        local *B::OP::test_init_attr = sub {
            my ($op) = @_;
            return unless $op->name eq 'init_attr';

            my $nameop = $op->first;
            die "unexpected child of init_attr"
                if $nameop->name ne 'const';

            my $sv = $nameop->sv;
            if (!$$sv) {
                $sv = $cv->PADLIST->ARRAYelt(1)->ARRAYelt($nameop->targ);
            }

            push @initialized, ${ $sv->object_2svref };
        };
        B::walkoptree($cv->ROOT, 'test_init_attr');
    }

    is_deeply([sort @initialized], [sort @attrs]);
}

done_testing;
