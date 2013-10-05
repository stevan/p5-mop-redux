#!perl

use strict;
use warnings;

use v5.14;

use Test::More;

use mop;

=pod

This totally doesn't use the mop much, but
I thought it was a fun use of given/when

=cut

my (@WARNINGS, @FATALS);
sub my_warn { push @WARNINGS => join "" => @_ }
sub my_die  { push @FATALS   => join "" => @_ }

class Logger {
    method log ( $level, $msg ) {
        no if $] >= 5.017011, warnings => 'experimental::smartmatch';
        given ( $level ) {
            when ( 'info'  ) { my_warn( '[info] ',    $msg ) }
            when ( 'warn'  ) { my_warn( '[warning] ', $msg ) }
            when ( 'error' ) { my_warn( '[error] ',   $msg ) }
            when ( 'fatal' ) { my_die(  '[fatal] ',   $msg ) }
            default {
                die "bad logging level: $level"
            }
        }
    }
}

class MyLogger extends Logger {
    method log ( $level, $msg ) {
        no if $] >= 5.017011, warnings => 'experimental::smartmatch';
        given ( $level ) {
            when ( 'info'  ) { my_warn( '<info> ', $msg ) }
            default {
                $self->next::method( $level, $msg );
            }
        }
    }
}

my $l = MyLogger->new;
$l->log(info => 'hey');
$l->log(warn => 'hey');

is_deeply(
    \@WARNINGS,
    [ '<info> hey', '[warning] hey' ],
    '... got the expected output'
);


done_testing;
