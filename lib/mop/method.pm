package mop::method;

use v5.16;
use warnings;

use Scalar::Util qw[ weaken ];

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use parent 'mop::object', 'mop::internals::observable';

mop::internals::util::init_attribute_storage(my %name);
mop::internals::util::init_attribute_storage(my %body);
mop::internals::util::init_attribute_storage(my %original_id);
mop::internals::util::init_attribute_storage(my %associated_meta);

# temporary, for bootstrapping
sub new {
    my $class = shift;
    my %args  = @_;
    my $self = $class->SUPER::new;
    $name{ $self } = \($args{'name'});
    $body{ $self } = \($args{'body'});
    # NOTE:
    # keep track of the original ID here
    # so that we can still detect method
    # conflicts in roles even after something
    # has been cloned
    # - SL
    $original_id{ $self } = \(mop::id($self));

    $self;
}

# temporary, for bootstrapping
sub clone {
    my $self = shift;
    return ref($self)->new(name => $self->name, body => $self->body);
}

sub name { ${ $name{ $_[0] } } }
sub body { ${ $body{ $_[0] } } }

sub associated_meta { ${ $associated_meta{ $_[0] } } }
sub set_associated_meta {
    my ($self, $meta) = @_;
    $associated_meta{ $self } = \$meta;
    weaken(${ $associated_meta{ $self } });
}

sub conflicts_with { ${ $original_id{ $_[0] } } ne ${ $original_id{ $_[1] } } }
sub locally_defined { ${ $original_id{ $_[0] } } eq mop::id( $_[0] ) }

sub execute {
    my ($self, $invocant, $args) = @_;

    $self->fire('before:EXECUTE' => $invocant, $args);

    my @result;
    my $wantarray = wantarray;
    if ( $wantarray ) {
        @result = $self->body->( $invocant, @$args );
    } elsif ( defined $wantarray ) {
        $result[0] = $self->body->( $invocant, @$args );
    } else {
        $self->body->( $invocant, @$args );
    }

    $self->fire('after:EXECUTE' => $invocant, $args, \@result);

    return $wantarray ? @result : $result[0];
}

our $METACLASS;

sub __INIT_METACLASS__ {
    return $METACLASS if defined $METACLASS;
    require mop::class;
    $METACLASS = mop::class->new(
        name       => 'mop::method',
        version    => $VERSION,
        authority  => $AUTHORITY,
        superclass => 'mop::object'
    );

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!name',
        storage => \%name
    ));

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!body',
        storage => \%body
    ));

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!associated_meta',
        storage => \%associated_meta
    ));

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!original_id',
        storage => \%original_id,
        default => \sub { mop::id($_) },
    ));

    $METACLASS->add_method( mop::method->new( name => 'name',                body => \&name                ) );
    $METACLASS->add_method( mop::method->new( name => 'body',                body => \&body                ) );
    $METACLASS->add_method( mop::method->new( name => 'associated_meta',     body => \&associated_meta     ) );
    $METACLASS->add_method( mop::method->new( name => 'set_associated_meta', body => \&set_associated_meta ) );
    $METACLASS->add_method( mop::method->new( name => 'conflicts_with',      body => \&conflicts_with      ) );
    $METACLASS->add_method( mop::method->new( name => 'locally_defined',     body => \&locally_defined     ) );

    $METACLASS->add_method( mop::method->new( name => 'execute', body => \&execute ) );

    $METACLASS;
}

1;

__END__

=pod

=head1 NAME

mop::method - A meta-object to represent methods

=head1 DESCRIPTION

TODO

=head1 METHODS

=over 4

=item C<BUILD>

=item C<clone(%overrides)>

=item C<name>

=item C<body>

=item C<associated_meta>

=item C<set_associated_meta($meta)>

=item C<conflicts_with($obj)>

=item C<locally_defined>

=item C<execute($invocant, $args)>

=back

=head1 SEE ALSO

=head2 L<Method Details|mop::manual::details::methods>

=head1 BUGS

Since this module is still under development we would prefer to not
use the RT bug queue and instead use the built in issue tracker on
L<Github|http://www.github.com>.

=head2 L<Git Repository|https://github.com/stevan/p5-mop-redux>

=head2 L<Issue Tracker|https://github.com/stevan/p5-mop-redux/issues>

=head1 AUTHOR

Stevan Little <stevan.little@iinteractive.com>

Jesse Luehrs <doy@tozt.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Infinity Interactive.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=for Pod::Coverage
  new

=cut





