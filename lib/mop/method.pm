package mop::method;

use strict;
use warnings;

use parent 'mop::object';

sub new {
    my $class = shift;
    my %args  = @_;
    $class->SUPER::new(
        name => $args{'name'},
        body => $args{'body'}
    );
}

sub name { (shift)->{'name'} }
sub body { (shift)->{'body'} }

1;

__END__