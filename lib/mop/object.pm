package mop::object;

use strict;
use warnings;

use mop::util qw[ find_meta get_mro_for ];

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

sub new {
    my $class = shift;
    my %args  = @_;
    if ($class =~ /^mop::/) {
        bless \%args => $class;    
    } else {
        my $self = bless \(my $x) => $class;

        #warn "GOT CLASS: " . $class;

        my %attributes = map { 
            #warn $_;
            if (my $m = find_meta($_)) {
                %{ $m->attributes }
            }
        } reverse @{ get_mro_for($class) };

        foreach my $attr (values %attributes) { 
            if ( exists $args{ $attr->key_name }) {
                $attr->storage->{ $self } = \($args{ $attr->key_name });
            } else {
                $attr->storage->{ $self } = \($attr->get_default) 
                    if $attr->has_default
            }
        }

        #use Data::Dumper 'Dumper';
        #warn "Hi - " . Dumper\%attributes;

        $self;
    }
}

our $METACLASS;

sub metaclass {
    return $METACLASS if defined $METACLASS;
    require mop::class;
    $METACLASS = mop::class->new( 
        name       => 'mop::object',
        version    => $VERSION,
        authrority => $AUTHORITY,
    );
    $METACLASS->add_method( mop::method->new( name => 'new', body => \&new ) );
    $METACLASS;
}

1;

__END__