package mop::internals::method;

use strict;
use warnings;

sub new {
    my $class = shift;
    my %args  = @_;
    bless {
        name => $args{'name'},
        body => $args{'body'}
    } => $class;
}

sub name { (shift)->{'name'} }
sub body { (shift)->{'body'} }

1;

__END__