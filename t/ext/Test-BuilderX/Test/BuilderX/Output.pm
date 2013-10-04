use strict;
use warnings;
use mop;

use IO::Handle;

class Test::BuilderX::Output {
    has $!output;
    has $!error_output;

    method BUILD {
        $!output = IO::Handle->new;
        $!output->fdopen( fileno( STDOUT ), "w" );

        $!error_output = IO::Handle->new;
        $!error_output->fdopen( fileno( STDERR ), "w" );
    }

    # XXX - should we add a DEMOLISH
    # here to close the file handles?

    method write ( $message ) {
        $message =~ s/\n(?!#)/\n# /g;
        $!output->print( $message, "\n" );
    }

    method diag ( $message ) {
        $message =~ s/^(?!#)/# /;
        $message =~ s/\n(?!#)/\n# /g;
        $!output->print( $message, "\n" );
    }
}

1;
