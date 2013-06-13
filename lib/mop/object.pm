package mop::object;

use strict;
use warnings;

sub new {
    my $class = shift;
    my %args  = @_;
    bless \%args => $class;
}

1;

__END__