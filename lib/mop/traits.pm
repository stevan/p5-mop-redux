package mop::traits;

use v5.16;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

our @AVAILABLE_TRAITS = qw[ 
    rw 
    ro 
    weak_ref
    lazy
    abstract 
    overload 
    extending_non_mop
];

sub rw {
    if ($_[0]->isa('mop::attribute')) {
        my ($attr) = @_;
        my $meta = $attr->associated_meta;
        $meta->add_method(
            $meta->method_class->new(
                name => $attr->key_name,
                body => sub {
                    my $self = shift;
                    $attr->store_data_in_slot_for($self, shift) if @_;
                    $attr->fetch_data_in_slot_for($self);
                }
            )
        );
    }
    elsif ($_[0]->isa('mop::class')) {
        my ($meta) = @_;
        foreach my $attr ( values %{ $meta->attributes } ) {
            $meta->add_method(
                $meta->method_class->new(
                    name => $attr->key_name,
                    body => sub {
                        my $self = shift;
                        $attr->store_data_in_slot_for($self, shift) if @_;
                        $attr->fetch_data_in_slot_for($self);
                    }
                )
            );
        }
    }
}

sub ro {
    if ($_[0]->isa('mop::attribute')) {
        my ($attr) = @_;
        my $meta = $attr->associated_meta;
        $meta->add_method(
            $meta->method_class->new(
                name => $attr->key_name,
                body => sub {
                    my $self = shift;
                    die "Cannot assign to a read-only accessor" if @_;
                    $attr->fetch_data_in_slot_for($self);
                }
            )
        );
    }
    elsif ($_[0]->isa('mop::class')) {
        my ($meta) = @_;
        foreach my $attr ( values %{ $meta->attributes } ) {
            $meta->add_method(
                $meta->method_class->new(
                    name => $attr->key_name,
                    body => sub {
                        my $self = shift;
                        die "Cannot assign to a read-only accessor" if @_;
                        $attr->fetch_data_in_slot_for($self);
                    }
                )
            );
        }
    }
}

sub abstract {
    if ($_[0]->isa('mop::class')) {
        my $meta = shift;
        $meta->make_class_abstract;
    }
}

sub overload {
    if ($_[0]->isa('mop::method')) {
        my ($method, $operator) = @_;

        # NOTE:
        # We are actually installing the overloads
        # into the package directly, this works
        # because the MRO stuff doesn't actually
        # get used if the the methods are local
        # to the package. This should avoid some
        # complexity (perhaps).

        # don't load it unless you
        # have too, it adds a speed
        # penalty to the runtime
        require overload;
        overload::OVERLOAD(
            $method->associated_meta->name,
            $operator,
            sub { $method->execute( shift( @_ ), [ @_ ] ) },
            fallback => 1
        );
    } elsif ($_[0]->isa('mop::class')) {
        my $meta = shift;
        ($_[0] eq 'inherited')
            || die "I don't know what to do with $_[0]";

        ($meta->superclass)
            || die "You don't have a superclass on " . $meta->name;

        my $local_stash = mop::util::get_stash_for( $meta->name );
        my $super_stash = mop::util::get_stash_for( $meta->superclass );
        my $all_symbols = $super_stash->get_all_symbols('CODE');

        foreach my $symbol ( grep { /^\(/ && !/^\(\)/ && !/^\(\(/ } keys %$all_symbols ) {
            unless ($local_stash->has_symbol( '&' . $symbol )) {
                my ($operator) = ($symbol =~ /^\((.*)/);
                overload::OVERLOAD(
                    $meta->name,
                    $operator,
                    $all_symbols->{ $symbol },
                    fallback => 1
                );
            }   
        }
    }
}

sub weak_ref {
    if ($_[0]->isa('mop::attribute')) {
        my ($attr) = @_;
        $attr->bind('after:STORE_DATA' => sub {
            Scalar::Util::weaken( ${ $_[0]->storage->{ $_[1] } } );
        });
    }
}

sub lazy {
    if ($_[0]->isa('mop::attribute')) {
        my $meta    = shift;
        my $default = $meta->clear_default;
        $meta->bind('before:FETCH_DATA' => sub {
            my (undef, $instance) = @_;
            if (not( exists $meta->storage->{$instance} ) || not( defined ${ $meta->storage->{$instance} } )) {
                $meta->store_data_in_slot_for($instance, $default->());
            }
        });
    }
}

sub extending_non_mop {
    if ($_[0]->isa('mop::class')) {
        state $BUILDALL = mop::get_meta('mop::object')->get_method('BUILDALL');
        
        my $meta              = shift;
        my $constructor_name  = shift // 'new';
        my $super_constructor = join '::' => $meta->superclass, $constructor_name;

        $meta->add_method(
            $meta->method_class->new(
                name => $constructor_name,
                body => sub {
                    my $class = shift;
                    my $self  = $class->$super_constructor( @_ );
                    $BUILDALL->execute( $self, [ @_ ] );
                    $self;
                }
            )
        );
    }
}

1;

__END__

=pod

=head1 NAME

mop::traits - collection of traits for the mop

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



