package mop::method;

use v5.16;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Scalar::Util qw[ weaken ];
use mop::internals::util;

our $VERSION   = '0.03';
our $AUTHORITY = 'cpan:STEVAN';

use parent 'mop::object', 'mop::internals::observable';

mop::internals::util::init_attribute_storage(my %name);
mop::internals::util::init_attribute_storage(my %body);
mop::internals::util::init_attribute_storage(my %associated_meta);
mop::internals::util::init_attribute_storage(my %original_id);

sub name            ($self) { ${ $name{ $self }            // \undef } }
sub body            ($self) { ${ $body{ $self }            // \undef } }
sub associated_meta ($self) { ${ $associated_meta{ $self } // \undef } }

sub set_associated_meta ($self, $meta) {
    $associated_meta{ $self } = \$meta;
    weaken(${ $associated_meta{ $self } });
}

# temporary, for bootstrapping
sub new ($class, %args) {
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
sub clone ($self, %) {
    return ref($self)->new(name => $self->name, body => $self->body);
}

sub execute ($self, $invocant, $args) {

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

sub conflicts_with ($self, $other) {
    ${ $original_id{ $self } } ne ${ $original_id{ $other } }
}

sub locally_defined ($self) {
    ${ $original_id{ $self } } eq mop::id( $self )
}

sub __INIT_METACLASS__ ($) {
    my $METACLASS = mop::class->new(
        name       => 'mop::method',
        version    => $VERSION,
        authority  => $AUTHORITY,
        superclass => 'mop::object',
    );

    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!name',
        storage => \%name,
    ));
    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!body',
        storage => \%body,
    ));
    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!associated_meta',
        storage => \%associated_meta,
    ));
    $METACLASS->add_attribute(mop::attribute->new(
        name    => '$!original_id',
        storage => \%original_id,
        default => sub { mop::id($_) },
    ));

    $METACLASS->add_method( mop::method->new( name => 'name', body => \&name ) );

    $METACLASS->add_method( mop::method->new( name => 'body',    body => \&body    ) );
    $METACLASS->add_method( mop::method->new( name => 'execute', body => \&execute ) );

    $METACLASS->add_method( mop::method->new( name => 'associated_meta',     body => \&associated_meta     ) );
    $METACLASS->add_method( mop::method->new( name => 'set_associated_meta', body => \&set_associated_meta ) );

    $METACLASS->add_method( mop::method->new( name => 'conflicts_with',  body => \&conflicts_with  ) );
    $METACLASS->add_method( mop::method->new( name => 'locally_defined', body => \&locally_defined ) );

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

=item C<name>

=item C<body>

=item C<execute($invocant, $args)>

=item C<associated_meta>

=item C<set_associated_meta($meta)>

=item C<conflicts_with($obj)>

=item C<locally_defined>

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

Florian Ragwitz <rafl@debian.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013-2014 by Infinity Interactive.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=for Pod::Coverage
  new
  clone

=cut
