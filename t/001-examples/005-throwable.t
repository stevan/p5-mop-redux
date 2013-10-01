#!perl

use strict;
use warnings;

use Test::More;

BEGIN {
    eval { require Devel::StackTrace; 1 }
        or ($ENV{RELEASE_TESTING}
            ? die
            : plan skip_all => "This test requires Devel::StackTrace");
}

use mop;

# XXX for some incredibly confusing reason, adding a do { } block to the
# default for $!stack_trace makes the stack trace start from the 'has'
# declaration, while leaving it off makes it start from the place that ->throw
# was called. no idea at all what causes this... possibly a bug in
# Parse::Keyword, but i can't reproduce it outside of here. "just another thing
# to fix in the real implementation" i guess.
class Throwable {

    has $!message     is ro = '';
    has $!stack_trace is ro = Devel::StackTrace->new(
        frame_filter => sub {
            $_[0]->{'caller'}->[3] !~ /^mop\:\:/ &&
            $_[0]->{'caller'}->[0] !~ /^mop\:\:/
        }
    );

    method throw     { die $self }
    method as_string { $!message . "\n\n" . $!stack_trace->as_string }
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
# for whatever reason, Devel::StackTrace does this internally, which converts
# forward slashes into backslashes on windows
$file = File::Spec->canonpath($file);

my $line1 = $line + 2;
my $line2 = $line + 4;
my $line3 = $line + 4;
like(
    $e->stack_trace->as_string,
    qr[^Trace begun at \Q$file\E line \Q$line1\E
main::bar at \Q$file\E line \Q$line2\E
eval {\.\.\.} at \Q$file\E line \Q$line3\E
],
    '... got the exception'
);

done_testing;

