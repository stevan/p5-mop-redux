package mop::object;

use v5.16;
use warnings;

use mop::util qw[ find_meta ];

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

sub new {
    my $class = shift;
    my %args  = @_;
    if ($class =~ /^mop::/) {
        bless \%args => $class;    
    } else {
        my $self = bless \(my $x) => $class;

        my %attributes = map { 
            if (my $m = find_meta($_)) {
                %{ $m->attributes }
            }
        } reverse @{ mop::mro::get_linear_isa($class) };

        foreach my $attr (values %attributes) { 
            if ( exists $args{ $attr->key_name }) {
                $attr->store_data_in_slot_for( $self, $args{ $attr->key_name } )
            } else {
                $attr->store_default_in_slot_for( $self );
            }
        }

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