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


our $METACLASS;

sub meta {
    return $METACLASS if defined $METACLASS;
    require mop::class;
    $METACLASS = mop::class->new( 
        name       => 'mop::method',
        version    => $VERSION,
        authrority => $AUTHORITY,        
        superclass => 'mop::object'
    );
    $METACLASS->add_method( mop::method->new( name => 'new',  body => \&new ) );
    $METACLASS->add_method( mop::method->new( name => 'name', body => \&name ) );
    $METACLASS->add_method( mop::method->new( name => 'body', body => \&body ) );
    $METACLASS;
}

1;

__END__