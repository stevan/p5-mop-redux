package mop;

use v5.16;
use mro;
use warnings;

use overload ();
use Scalar::Util ();

our $VERSION   = '0.02';
our $AUTHORITY = 'cpan:STEVAN';

our $BOOTSTRAPPED = 0;

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

use mop::object;
use mop::class;
use mop::method;
use mop::attribute;

use mop::internals::observable;

use mop::internals::syntax;
use mop::internals::util;

use mop::traits;
use mop::traits::util;

sub import {
    shift;
    my $pkg = caller;
    my %opts = @_;

    initialize();
    mop::internals::syntax::setup_for($pkg);
    mop::traits::setup_for($pkg);

    # NOTE: don't allow setting attribute or method metaclasses here, because
    # that is controlled by the class or role metaclass via method_class and
    # attribute_class.
    for my $type (qw(class role)) {
        if (defined(my $meta = $opts{"${type}_metaclass"})) {
            require(($meta =~ s{::}{/}gr) . '.pm');
            $^H{"mop/default_${type}_metaclass"} = $meta;
        }
    }
}

sub unimport {
    my $pkg = caller;
    mop::internals::syntax::teardown_for($pkg);
    mop::traits::teardown_for($pkg);
}

sub meta {
    my $pkg = ref($_[0]) || $_[0];
    mop::internals::util::get_meta($pkg);
}

sub remove_meta {
    my $pkg = ref($_[0]) || $_[0];
    mop::internals::util::unset_meta($pkg);
}

sub id { Hash::Util::FieldHash::id( $_[0] ) }

sub is_mop_object {
    defined Hash::Util::FieldHash::id_2obj( id( $_[0] ) );
}

sub apply_metaclass {
    # TODO: we should really not be calling apply_metaclass at all during
    # bootstrapping, but it's done in a couple places for simplicity, to avoid
    # needing multiple implementations of things for pre- and
    # post-bootstrapping. we should probably eventually actually do the
    # replacement in those methods, to make sure bootstrapping isn't doing
    # unnecessary extra work. the actual implementation is replaced below.
    return;
}

sub rebless {
    my ($object, $into) = @_;

    my $from = Scalar::Util::blessed($object);
    my $common_base = mop::internals::util::find_common_base($from, $into);

    my @from_isa = @{ mro::get_linear_isa($from) };
    if ($common_base) {
        pop @from_isa until $from_isa[-1] eq $common_base;
        pop @from_isa;
    }
    @from_isa = grep { defined } map { meta($_) } @from_isa;

    my @into_isa = @{ mro::get_linear_isa($into) };
    if ($common_base) {
        pop @into_isa until $into_isa[-1] eq $common_base;
        pop @into_isa;
    }
    @into_isa = grep { defined } map { meta($_) } @into_isa;

    for my $attr (map { $_->attributes } @from_isa) {
        $attr->store_data_in_slot_for($object, undef);
    }

    bless($object, $into);

    for my $attr (map { $_->attributes } reverse @into_isa) {
        $attr->store_default_in_slot_for($object);
    }

    $object
}

sub dump_object {
    my ($obj) = @_;

    return $obj unless is_mop_object($obj);

    our %SEEN;
    if ($SEEN{id($obj)}) {
        return '<cycle_fix>';
    }
    local $SEEN{id($obj)} = ($SEEN{id($obj)} // 0) + 1;

    my %attributes = map {
        if (my $m = meta($_)) {
            %{ $m->attribute_map }
        }
    } reverse @{ mro::get_linear_isa(ref $obj) };

    my $temp = {
        __ID__    => id($obj),
        __CLASS__ => meta($obj)->name,
        __SELF__  => $obj,
    };

    foreach my $attr (values %attributes) {
        if ($obj->isa('mop::attribute') && $attr->name eq '$!storage') {
            $temp->{ $attr->name } = '__INTERNAL_DETAILS__';
        } else {
            $temp->{ $attr->name } = sub {
                my ($data) = @_;
                if (Scalar::Util::blessed($data)) {
                    return dump_object($data);
                } elsif (ref $data) {
                    if (ref $data eq 'ARRAY') {
                        return [ map { __SUB__->( $_ ) } @$data ];
                    } elsif (ref $data eq 'HASH') {
                        return {
                            map { $_ => __SUB__->( $data->{$_} ) } keys %$data
                        };
                    } else {
                        return $data;
                    }
                } else {
                    return $data;
                }
            }->( $attr->fetch_data_in_slot_for( $obj ) );
        }
    }

    $temp;
}

# can't call this 'bootstrap' because XSLoader has a special meaning for that
sub initialize {
    return if $BOOTSTRAPPED;
    mop::internals::util::set_meta($_, $_->__INIT_METACLASS__) for qw[
        mop::object
        mop::role
        mop::class
        mop::attribute
        mop::method
        mop::internals::observable
    ];

    my $Object = meta('mop::object');

    my $Role  = meta('mop::role');
    my $Class = meta('mop::class');

    my $Method     = meta('mop::method');
    my $Attribute  = meta('mop::attribute');
    my $Observable = meta('mop::internals::observable');

    # flatten mop::observable into wherever it's needed (it's just an
    # implementation detail (#95), so it shouldn't end up being directly
    # visible)
    foreach my $meta ( $Role, $Attribute, $Method ) {
        for my $attribute ( $Observable->attributes ) {
            $meta->add_attribute($attribute->clone(associated_meta => $meta));
        }
        for my $method ( $Observable->methods ) {
            $meta->add_method($method->clone(associated_meta => $meta));
        }
    }

    # At this point the metaclass
    # layer class to role relationship
    # is correct. And the following
    #   - Class does Role
    #   - Role is instance of Class
    #   - Role does Role
    # is true.
    $Class->add_role( $Role );

    # normally this would be a call to FINALIZE for all of the mop classes,
    # but that complicates things too much during bootstrapping, and this
    # is the only thing that would have an actual effect anyway.
    mop::internals::util::apply_all_roles($Class, $Role);

    # and now this is no longer needed
    remove_meta('mop::internals::observable');

    {
        # NOTE:
        # This is ugly, but we need to do
        # it to set the record straight
        # and make sure that the relationship
        # between mop::class and mop::role
        # are correct and code is reused.
        # - SL
        foreach my $method ($Role->methods) {
            no strict 'refs';
            *{ 'mop::class::' . $method->name } = $method->body
                unless defined &{ 'mop::class::' . $method->name };
        }

        # now make sure the Observable roles are
        # completely intergrated into the stashes
        foreach my $method ($Observable->methods) {
            foreach my $package (qw(mop::role mop::method mop::attribute)) {
                no strict 'refs';
                *{ $package . '::' . $method->name } = $method->body
                    unless defined &{ $package . '::' . $method->name };
            }
        }

        # then clean up some of the @ISA by
        # removing mop::observable from them
        @mop::role::ISA      = ('mop::object');
        @mop::method::ISA    = ('mop::object');
        @mop::attribute::ISA = ('mop::object');

        # Here we finalize the rest of the
        # metaclass layer so that the following:
        #   - Class is an instance of Class
        #   - Object is an instance of Class
        #   - Class is a subclass of Object
        # is true.
        @mop::class::ISA = ('mop::object');

        # remove the temporary clone methods used in the bootstrap
        delete $mop::method::{clone};
        delete $mop::attribute::{clone};

        # replace the temporary implementation of mop::object::new
        {
            no strict 'refs';
            no warnings 'redefine';
            *{ 'mop::object::new' } = $Object->get_method('new')->body;
        }

        # remove the temporary constructors used in the bootstrap
        delete $mop::class::{new};
        delete $mop::role::{new};
        delete $mop::method::{new};
        delete $mop::attribute::{new};
    }

    {
        no warnings 'redefine';
        *apply_metaclass = mop::internals::util::subname(
            apply_metaclass => sub {
                my ($instance, $new_meta) = @_;
                rebless $instance, mop::internals::util::fix_metaclass_compatibility($new_meta, $instance);
            }
        );
    }

    $BOOTSTRAPPED = 1;
}

# B::Deparse doesn't know what to do with custom ops
{
    package
        B::Deparse;
    sub pp_init_attr { "INIT_ATTR " . maybe_targmy(@_, \&unop) }
}

1;

__END__

=pod

=head1 NAME

mop - A new object system for Perl 5

=head1 VERSION

version 0.02

=head1 SYNOPSIS

    use mop;

    class Point {
        has $!x is ro = 0;
        has $!y is ro = 0;

        method clear {
            ($!x, $!y) = (0, 0);
        }
    }

    class Point3D extends Point {
        has $!z is ro = 0;

        method clear {
            $self->next::method;
            $!z = 0;
        }
    }

=head1 STATEMENT OF INTENT

This is a prototype for a new object system for Perl 5, it is our
intent to try and get this into the core of Perl 5. This is being
released to CPAN so that the community at large can test it out
and provide feedback.

It can B<not> be overstated that this is a 0.01 prototype, which
means that nothing here is final and everything could change.
That said we are quite happy with the current state and after
several months of working with it, feel that it is solid enough
to go out to CPAN and withstand the cold harsh light of day.

=head1 FAQs

=head2 How can I help?

Thanks for asking, there are several things that you can do to
help!

=head3 Contributing/reviewing documentation

Documentation is not one of our strong suits, any help on this
would be very much appreciated. Especially documetation written
from the perspective of users without prior knowledge of MOPs
and/or Moose.

Please send any and all patches as pull requests to our
L<repository on github|https://github.com/stevan/p5-mop-redux>.

=head3 Porting a module

Early on in the development of this we started porting existing
Perl OO modules to use the mop. This proved to be a really
excellent way of uncovering edge cases and issues. We currently
have 9 ported modules in our L<Travis|https://travis-ci.org>
smoke test and are always looking for more.

If you do port something, please let us know via the
L<github issue tracker|https://github.com/stevan/p5-mop-redux/issues>
so that we can add it to our smoke tests.

=head3 Writing a module

Porting existing modules to the mop is interesting, but we are
also interested in having people try it out from scratch. We
currently only have 1 original module in our L<Travis|https://travis-ci.org>
smoke test and are always looking for more.

If you do write something using the mop, please let us know via the
L<github issue tracker|https://github.com/stevan/p5-mop-redux/issues>
so that we can add it to our smoke tests.

=head3 Speak to us

We are always open for a reasonable, civil discourse on what it
is we are trying to do here. If you have ideas or issues with
anything you see here please submit your thoughts via the
L<github issue tracker|https://github.com/stevan/p5-mop-redux/issues>
so that it can be discussed.

Trolls are welcome, but beware, we may try to
L<hug you|http://pugs.blogs.com/audrey/2009/08/my-hobby-troll-hugging.html>!

=head3 Hack with us

There are still many things to be done, if you want to help we
would love to have it. Please stop by and see us in the #p5-mop
channel on irc.perl.org to discuss. Specifically we are looking for
XS hacker and perlguts specialists.

=head3 Spread the word

The Perl community is a notorious echo chamber, itself filled with
smaller, more specific, echo chambers (OMG - it's echo chambers all
the way down!). If you are reading this, clearly you are inside, or
in the vicinity of, this particular echo chamber and so please if
you like what we are doing, spread the word. Write a blog post,
send a tweet into the ether, give a talk at your local tech meetup,
anything that helps get the word out is a good thing.

Side note: We have been using the #p5mop hashtag on twitter and in
blog posts, please continue that trend so things can be easily
aggregated.

=head2 Why aren't you supporting @features from $my_favorite_oo_module?

It is our intention to keep the core mop as simple as possible
and to allow for users to easily extend it to support their
favorite features. If you have any questions about writing said
extensions or feel that we are really should support a given
feature in core, please submit an issue to the
L<github issue tracker|https://github.com/stevan/p5-mop-redux/issues>
so that it can be discussed.

=head2 Why are you messing up Perl, I like it how it is!?!?!

We are absolutely 100% B<NOT> going to remove B<any> of the existing OO
support in Perl I<FULL STOP>.

We are developing this feature fully in keeping with the long standing
commitment to backward compatibility that Perl is famous for. We are
also committed to making this new object system work as seamlessly as
possible with all of the existing Perl OO features.

=head2 Why is it so slow?

It is a prototype, first we had to get it right, next we will make
it fast. We have a number of planned optimizations in the works and
are confident that ultimately speed will not be an issue.

=head2 Can I use this in production?

Probably not a good idea, but hey, it's your codebase. If you are crazy
enough to do this, please let us know how it goes!

=head2 What version of Perl do you expect this to ship with?

Well, we would like it to be included as experimental in 5.22, but
that might be a little tight, time will tell. In the meantime we will
try and keep supporting a CPAN version as long as it is possible.

=head1 PUBLIC UTILITY FUNCTIONS

The following is a list of public utility functions to
be used along with the MOP.

=head2 meta($obj_or_class_name)

Given an object instance or a class name, this will return
the meta-object associated with it. If there is no meta-object
associated with it, meaning it is not a MOP class or role,
then undef will be returned.

=head2 id($obj)

Given an instance this will return the unique ID given
to that instance. This ID is the key used throughout many
of the MOP internals to identify this instance.

=head2 is_mop_object($obj)

This predicate will return true of the instance if a MOP
object, and false otherwise.

=head2 dump_object($obj)

This is a simple utility function that takes an instance
and returns a HASH ref dump of the data contained within
the instance. This is necessary because MOP instances are
opaque and cannot be dumped using the existing tools
(ex: Data::Dumper, etc.).

NOTE: This is a temporary situation, once this system is
accepted into core, we expect that the tools will add
support accordingly.

=head1 OTHER FUNCTIONS

The following are functions that are unlikely to be useful
to any but the most daring of users. Use with great caution!

=head2 apply_metaclass($obj, $metaclass_name_or_instance)

Given an instance and a class name, this will perform all
the necessary metaclass compatibility checks and then
rebless the instance accordingly.

=head2 rebless($obj, $class_name)

Given an instance and a class name, this will handle
reblessing the instance into the class and assure that
all the correct initializations are done.

=head2 remove_meta($class_name)

This will remove the metaclass associated with a given
C<$class_name>, after this C<meta> will return undef.

=head2 initialize()

This will bootstrap the MOP, you really should never call this
we will do it for you.

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

=cut



