package mop::method;

use strict;
use warnings;

use parent 'mop::object';

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