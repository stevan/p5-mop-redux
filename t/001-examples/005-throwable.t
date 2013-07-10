#!perl

use strict;
use warnings;

use Test::More;
use Test::Requires 'Devel::StackTrace';

use mop;

class Throwable {

    has $message     is ro = '';
    has $stack_trace is ro = do {
        Devel::StackTrace->new(
            frame_filter => sub {
                $_[0]->{'caller'}->[3] !~ /^mop\:\:/ &&
                $_[0]->{'caller'}->[0] !~ /^mop\:\:/
            }
        )
    };

    method throw     { die $self }
    method as_string { $message . "\n\n" . $stack_trace->as_string }
}

my $line = __LINE__;
sub foo { Throwable->new( message => "HELLO" )->throw }
sub bar { foo() }

eval { bar() };
my $e = $@;

ok( $e->isa( 'Throwable' ), '... the exception is a Throwable object' );

is( $e->message, 'HELLO', '... got the exception' );

isa_ok( $e->stack_trace, 'Devel::StackTrace' );

my $file = __FILE__;
$file =~ s/^\.\///;

my $line1 = $line + 2 - 8;
my $line2 = $line + 2;
my $line3 = $line + 4;
my $line4 = $line + 4;
is(
    $e->stack_trace->as_string,
    qq[Trace begun at $file line $line1
main::foo at $file line $line2
main::bar at $file line $line3
eval {...} at $file line $line4
],
    '... got the exception'
);

done_testing;

