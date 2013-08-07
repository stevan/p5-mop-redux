package mop::class;

use v5.16;
use warnings;

use mop::util qw[ init_attribute_storage find_meta ];

use List::AllUtils qw[ uniq ];
use Module::Runtime qw[ is_module_name module_notional_filename ];

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use parent 'mop::role';

init_attribute_storage(my %is_abstract);
init_attribute_storage(my %superclass);
init_attribute_storage(my %submethods);

sub new {
    my $class = shift;
    my %args  = @_;
    my $self = $class->SUPER::new( @_ );
    $is_abstract{ $self } = \($args{'is_abstract'} // 0);
    $superclass{ $self }  = \($args{'superclass'});
    $submethods{ $self }  = \({});

    if ( defined( $args{'name'} ) && is_module_name( $args{'name'} ) ) {
        $INC{ module_notional_filename( $args{'name'} ) } //= '(mop)';
    }

    $self;
}

# identity

sub superclass { ${ $superclass{ $_[0] } } }

sub is_abstract { ${ $is_abstract{ $_[0] } } }

sub make_class_abstract { $is_abstract{ $_[0] } = \1 }

# instance creation

sub new_instance { (shift)->name->new( @_ ) }

# submethods

sub submethod_class { 'mop::method' }

sub submethods { ${ $submethods{ $_[0] } } }

sub add_submethod {
    my ($self, $submethod) = @_;
    $self->submethods->{ $submethod->name } = $submethod;
}

sub get_submethod {
    my ($self, $name) = @_;
    $self->submethods->{ $name }
}

sub has_submethod {
    my ($self, $name) = @_;
    exists $self->submethods->{ $name };
}

# events

sub FINALIZE {
    my $self = shift;
    $self->fire('before:FINALIZE');

    # inherit required methods ...
    if (my $super = $self->superclass) {
        if (my $meta = find_meta($super)) {
            if (scalar @{ $meta->required_methods }) {
                # merge required methods with superclass
                @{ $self->required_methods } = uniq(
                    @{ $self->required_methods },
                    @{ $meta->required_methods }
                );
            }
        }
    }

    $self->mop::role::FINALIZE;

    if (scalar @{ $self->required_methods } != 0 && not $self->is_abstract) {
        die 'Required method(s) [' 
            . (join ', ' => @{ $self->required_methods })
            . '] are not allowed in '
            . $self->name
            . ' unless class is declared abstract';
    }

    $self->fire('after:FINALIZE');
}

our $METACLASS;

sub __INIT_METACLASS__ {
    return $METACLASS if defined $METACLASS;
    require mop::class;
    $METACLASS = mop::class->new(
        name       => 'mop::class',
        version    => $VERSION,
        authority  => $AUTHORITY,
        superclass => 'mop::object'
    );

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$is_abstract',
        storage => \%is_abstract,
        default => \(0)
    ));

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$superclass',
        storage => \%superclass
    ));

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$submethods',
        storage => \%submethods,
        default => \sub { {} },
    ));

    # NOTE:
    # we do not include the new method, because
    # we want all meta-extensions to use the one
    # from mop::object.
    # - SL
    $METACLASS->add_method( mop::method->new( name => 'superclass', body => \&superclass ) );

    $METACLASS->add_method( mop::method->new( name => 'is_abstract',         body => \&is_abstract ) );
    $METACLASS->add_method( mop::method->new( name => 'make_class_abstract', body => \&make_class_abstract ) );

    $METACLASS->add_method( mop::method->new( name => 'new_instance', body => \&new_instance ) );

    $METACLASS->add_method( mop::method->new( name => 'submethod_class', body => \&submethod_class ) );
    $METACLASS->add_method( mop::method->new( name => 'submethods',      body => \&submethods      ) );
    $METACLASS->add_method( mop::method->new( name => 'get_submethod',   body => \&get_submethod   ) );
    $METACLASS->add_method( mop::method->new( name => 'add_submethod',   body => \&add_submethod   ) );
    $METACLASS->add_method( mop::method->new( name => 'has_submethod',   body => \&has_submethod   ) );

    $METACLASS->add_method( mop::method->new( name => 'FINALIZE', body => \&FINALIZE ) );

    $METACLASS;
}

1;

__END__

=pod

=head1 NAME

mop::class

=head1 DESCRIPTION

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 AUTHOR

Stevan Little <stevan@iinteractive.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Infinity Interactive.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut





