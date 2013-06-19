package mop::object;

use strict;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

sub new {
    my $class = shift;
    my %args  = @_;
    bless \%args => $class;
}

our $__META__;

sub meta {
    return $__META__ if defined $__META__;
    require mop::class;
    $__META__ = mop::class->new( 
        name       => 'mop::object',
        version    => $VERSION,
        authrority => $AUTHORITY,
    );
    $__META__->add_method( mop::method->new( name => 'new', body => \&new ) );
    $__META__;
}

1;

__END__