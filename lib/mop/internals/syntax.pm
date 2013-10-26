package mop::internals::syntax;

use v5.16;
use warnings;

use version           ();
use Devel::CallParser ();

our $VERSION   = '0.02';
our $AUTHORITY = 'cpan:STEVAN';

my @available_keywords = qw(class role method has);

# keep the local metaclass around
our $CURRENT_META;

sub setup_for {
    my ($pkg) = @_;

    $^H{__PACKAGE__ . '/twigils'} = 1;
    mop::internals::util::install_sub($pkg, 'mop::internals::syntax', $_)
        for @available_keywords;
}

sub teardown_for {
    my ($pkg) = @_;

    mop::internals::util::uninstall_sub($pkg, $_)
        for @available_keywords;
}

sub new_meta {
    my ($metaclass, $name, $version, $roles, $superclass) = @_;

    $metaclass->new(
        name       => $name,
        version    => $version,
        roles      => [map {
            mop::meta($_) or die "Could not find metaclass for role: $_"
          } @{ $roles }],
        (defined $superclass
            ? (superclass => $superclass)
            : ()),
    );
}

sub build_meta {
    my ($meta, $body, @traits) = @_;

    while (@traits) {
        my ($trait, $args) = splice @traits, 0, 2;
        mop::traits::util::apply_trait(
            $trait, $meta, $args ? @$args : (),
        );
    }

    $meta->FINALIZE;

    $body->();
}

sub add_method {
    my ($name, $body, @traits) = @_;

    if ($body) {
        $CURRENT_META->add_method(
            $CURRENT_META->method_class->new(
                name => $name,
                body => mop::internals::util::subname(
                    (join '::' => $CURRENT_META->name, $name),
                    $body,
                ),
            )
        );

        while (@traits) {
            my ($trait, $args) = splice @traits, 0, 2;
            mop::traits::util::apply_trait(
                $trait, $CURRENT_META->get_method($name), $args ? @$args : (),
            );
        }
    }
    else {
        $CURRENT_META->add_required_method($name);
    }

    return;
}

sub add_attribute {
    my ($name, $default, @traits) = @_;

    $CURRENT_META->add_attribute(
        $CURRENT_META->attribute_class->new(
            name    => $name,
            default => $default,
        )
    );

    while (@traits) {
        my ($trait, $args) = splice @traits, 0, 2;
        mop::traits::util::apply_trait(
            $trait, $CURRENT_META->get_attribute($name), $args ? @$args : (),
        );
    }

    return;
}

1;

__END__

=pod

=head1 NAME

mop::internals::syntax - internal use only

=head1 DESCRIPTION

This is for internal use only, there is no public API here.

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

This software is copyright (c) 2013 by Infinity Interactive.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=for Pod::Coverage .+

=cut







