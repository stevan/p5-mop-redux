package mop::method;

use strict;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

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


our $__META__;

sub meta {
    return $__META__ if defined $__META__;
    require mop::class;
    $__META__ = mop::class->new( 
        name       => 'mop::method',
        version    => $VERSION,
        authrority => $AUTHORITY,        
        superclass => 'mop::object'
    );
    $__META__->add_method( mop::method->new( name => 'new',  body => \&new ) );
    $__META__->add_method( mop::method->new( name => 'name', body => \&name ) );
    $__META__->add_method( mop::method->new( name => 'body', body => \&body ) );
    $__META__;
}

1;

__END__