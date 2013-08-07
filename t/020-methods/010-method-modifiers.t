#!perl

use strict;
use warnings;

use v5.16;

use Test::More;

use mop;

sub find_method_and_prepare_method {
    my ($meta, $method_name) = @_;
    my $method;
    my @mro = @{ mop::mro::get_linear_isa( $meta->name ) };
    shift @mro; # we already know there is no local copy
    foreach my $class ( @mro ) {
        if ( mop::util::has_meta( $class ) ) {
            my $meta = mop::util::find_meta( $class );
            if ($meta->has_method( $method_name )) {
                $method = $meta->get_method( $method_name );
                last;
            }
                
        } else {
            die "wrapping non MOP methods is not supported (yet)"
        }
    }

    my $new_method = $meta->method_class->new(
        name => $method->name,
        body => sub {
            my $self = shift;
            $method->execute( $self, [ @_ ] );
        },
    );

    $meta->add_method($new_method);

    $new_method;
}

sub before {
    if ($_[0]->isa('mop::method')) {
        state $BEFORE_CACHE = {};

        my $method = shift;
        my $meta   = $method->associated_meta;

        my $primary_method = $meta->has_method( $method->name ) 
            ? $meta->get_method( $method->name ) 
            : find_method_and_prepare_method( $meta, $method->name );

        if (!$primary_method) {
            die 'Cannot wrap ' . $method->name . ' because no primary method exists';
        }

        if ( exists $BEFORE_CACHE->{ $primary_method->id } ) {
            unshift @{ $BEFORE_CACHE->{ $primary_method->id } } => $method;    
        } else {
            $BEFORE_CACHE->{ $primary_method->id } = [];
            unshift @{ $BEFORE_CACHE->{ $primary_method->id } } => $method;
            $primary_method->bind('before:EXECUTE' => sub {
                foreach my $method (@{ $BEFORE_CACHE->{ $primary_method->id } }) {
                    $method->execute( $_[1], $_[2] );
                }
            });
        }

        return $primary_method;
    }
}

sub after {
    if ($_[0]->isa('mop::method')) {
        state $AFTER_CACHE = {};

        my $method = shift;
        my $meta   = $method->associated_meta;

        my $primary_method = $meta->has_method( $method->name ) 
            ? $meta->get_method( $method->name ) 
            : find_method_and_prepare_method( $meta, $method->name );

        if (!$primary_method) {
            die 'Cannot wrap ' . $method->name . ' because no primary method exists';
        }

        if ( exists $AFTER_CACHE->{ $primary_method->id } ) {
            push @{ $AFTER_CACHE->{ $primary_method->id } } => $method;    
        } else {
            $AFTER_CACHE->{ $primary_method->id } = [];
            push @{ $AFTER_CACHE->{ $primary_method->id } } => $method;
            $primary_method->bind('after:EXECUTE' => sub {
                foreach my $method (@{ $AFTER_CACHE->{ $primary_method->id } }) {
                    $method->execute( $_[1], $_[2] );
                }
            });
        }

        return $primary_method;
    }
}

sub around {
    if ($_[0]->isa('mop::method')) {

        my $method = shift;
        my $meta   = $method->associated_meta;

        my $primary_method = $meta->has_method( $method->name ) 
            ? $meta->get_method( $method->name ) 
            : find_method_and_prepare_method( $meta, $method->name );

        if (!$primary_method) {
            die 'Cannot wrap ' . $method->name . ' because no primary method exists';
        }

        my $orig_body = $primary_method->body;

        $primary_method->set_body(sub {
            local ${^NEXT} = $orig_body;
            my $self = shift;
            $method->execute( $self, [ @_ ] );
        });

        return $primary_method;
    }
}

my @OUTPUT;

class Food {
    method cook {
        push @OUTPUT => 'Cooking some food'
    }

    # before 1
    method cook is before  {
        push @OUTPUT => 'A food is about to be cooked';
    }

    # before 2
    method cook is before  {
        push @OUTPUT => 'Preparing to actually cook some food';
    }

    # after 1
    method cook is after {
        push @OUTPUT => 'A food has been cooked';
    }

    # after 2
    method cook is after {
        push @OUTPUT => 'okay, now time to clean up';
    }

    # around 1
    method cook is around {
        push @OUTPUT => 'Begin around food';
        ${^NEXT}->( @_ );
        push @OUTPUT => 'End around food';
    }

    # around 2
    method cook is around {
        push @OUTPUT => 'Begin around/around food';
        ${^NEXT}->( @_ );
        push @OUTPUT => 'End around/around food';
    }
}

my $food = Food->new;
isa_ok($food, 'Food');

$food->cook;

is_deeply(
    \@OUTPUT,
    [
        'Preparing to actually cook some food',
        'A food is about to be cooked', 
        'Begin around/around food', 
        'Begin around food', 
        'Cooking some food', 
        'End around food', 
        'End around/around food', 
        'A food has been cooked',
        'okay, now time to clean up', 
    ],
    '... got the right output'
);

# reset the output 
# for the next test
@OUTPUT = ();

class Pie extends Food {

    method cook is before {
        push @OUTPUT => 'A pie is about to be cooked';
    }

    method cook is after {
        push @OUTPUT => 'A pie has been cooked';
    }
}

my $pie = Pie->new;
isa_ok($pie, 'Pie');
isa_ok($pie, 'Food');

$pie->cook;

is_deeply(
    \@OUTPUT,
    [
        'A pie is about to be cooked',
        'Preparing to actually cook some food',
        'A food is about to be cooked', 
        'Begin around/around food', 
        'Begin around food', 
        'Cooking some food', 
        'End around food', 
        'End around/around food', 
        'A food has been cooked',
        'okay, now time to clean up', 
        'A pie has been cooked',
    ],
    '... got the right output'
);

done_testing;