#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

eval '
class Foo {
    has $!bar = [];
    method get_bar ($i) { $!bar[$i] }
}
';
like($@, qr/No such twigil variable \@!bar/);

eval '
class Foo {
    has $!bar = [];
    method get_bar ($i) { $!bar  [$i] }
}
';
like($@, qr/No such twigil variable \@!bar/);

eval '
class Foo {
    has $!bar = {};
    method get_bar ($k) { $!bar{$k} }
}
';
like($@, qr/No such twigil variable \%!bar/);

eval '
class Foo {
    has $!bar = {};
    method get_bar ($k) { $!bar  {$k} }
}
';
like($@, qr/No such twigil variable \%!bar/);

eval q[
class Bar {
    has $!filename = "/some/nonexistent/file";
    method open {
        open my $fh, "<", $!filename
            or die "Couldn't open $!filename: $!";
    }
}
];
is($@, '');

{
    my $bar = Bar->new;
    my $msg = do {
        local $!;
        open my $fh, '<', '/some/nonexistent/file';
        $!;
    };
    eval { $bar->open };
    like($@, qr{Couldn't open /some/nonexistent/file: \Q$msg});
}

done_testing;
