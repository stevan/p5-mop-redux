package mop::internals::syntax;

use v5.16;
use warnings;

use Scope::Guard    qw[ guard ];
use Variable::Magic qw[ wizard ];

use B::Hooks::EndOfScope ();
use Carp            ();
use Scalar::Util    ();
use Sub::Name       ();
use version         ();
use twigils 0.04    ();

use Parse::Keyword {
    class     => \&namespace_parser,
    role      => \&namespace_parser,
    method    => \&method_parser,
    has       => \&has_parser,
};

our @AVAILABLE_KEYWORDS = qw(class role method has);

# keep the local metaclass around
our $CURRENT_META;

# So this will apply magic to the aliased
# attributes that we put in the method
# preamble. For `data`, it takes an HASH-ref
# containing the invocant id, the current
# meta object and the name of the attribute
# we are trying to get/set. Then when our
# attribute variable is read from or written
# to it will get/set that data to the
# underlying fieldhash storage.
our $ATTR_WIZARD = wizard(
    data => sub {
        my (undef, $config) = @_;
        return $config;
    },
    get  => sub {
        my ($var, $config) = @_;
        my $attr = $config->{'meta'}->get_attribute( $config->{'name'} );
        ${ $var } = $attr->fetch_data_in_slot_for( $config->{'self'} );
        ();
    },
    set  => sub {
        my ($value, $config) = @_;
        my $attr = $config->{'meta'}->get_attribute( $config->{'name'} );
        $attr->store_data_in_slot_for( $config->{'self'}, ${ $value } );
        ();
    },
    # NOTE:
    # this can be usedful at times,
    # but no need to take the perf
    # hit if we don't need it.
    # - SL
    #op_info => Variable::Magic::VMG_OP_INFO_NAME
);

# this wizard if for class methods only
# that throws an error if the user tries
# to access or assign to an attribute
our $ERR_WIZARD = wizard(
    data => sub {
        my (undef, $name) = @_;
        return $name;
    },
    get  => sub {
        my (undef, $name) = @_;
        die "Cannot access the attribute:($name) in a method without a blessed invocant";
        ();
    },
    set  => sub {
        my (undef, $name) = @_;
        die "Cannot assign to the attribute:($name) in a method without a blessed invocant";
        ();
    },
);

sub class { 1 }

sub role { 1 }

sub namespace_parser {
    my ($type) = @_;

    lex_read_space;

    my $name   = parse_name($type, 1);
    my $caller = compiling_package;
    my $pkg    = $name =~ /::/
        ? $name =~ s/^:://r
        : join "::" => ($caller eq 'main' ? () : ($caller)), $name;

    lex_read_space;

    my $version;
    if (lex_peek(40) =~ / \A ($version::LAX) (?:\s|\{) /x) {
        lex_read(length($1));
        $version = version::is_strict($1) ? eval($1) : $1 eq 'undef' ? undef : $1;
    }

    lex_read_space;

    my @classes_to_load;

    my $extends;
    if ($type eq 'class') {
        if ($extends = parse_modifier_with_single_value('extends')) {
            push @classes_to_load => $extends;
        }
        else {
            $extends = 'mop::object';
        }

        lex_read_space;
    }
    else {
        if (lex_peek(8) =~ /^extends\b/) {
            syntax_error("Roles cannot use 'extends'");
        }
    }

    my @with;
    if (@with = parse_modifier_with_multiple_values('with')) {
        push @classes_to_load => @with;
    }

    lex_read_space;

    my $metaclass;
    if ($metaclass = parse_modifier_with_single_value('meta')) {
        push @classes_to_load => $metaclass;
    }
    else {
        $metaclass = "mop::$type";
    }

    lex_read_space;

    my @traits = parse_traits();

    lex_read_space;

    for my $class (@classes_to_load) {
        next if mop::meta($class);
        require(($class =~ s{::}{/}gr) . '.pm');
    }

    syntax_error("$type must be followed by a block")
        unless lex_peek eq '{';

    lex_read;

    die "The metaclass for $pkg does not inherit from mop::$type"
        unless $metaclass->isa("mop::$type");

    my $meta = $metaclass->new(
        name       => $pkg,
        version    => $version,
        roles      => [ map { mop::meta($_) or die "Could not find metaclass for role: $_" } @with ],
        ($type eq 'class'
            ? (superclass => $extends)
            : ()),
    );
    my $g = guard {
        mop::remove_meta($pkg);
    };

    my $preamble = '{'
        . 'sub __' . uc($type) . '__ () { "' . $pkg . '" }'
        . 'BEGIN {'
        .     'B::Hooks::EndOfScope::on_scope_end {'
        .         'no strict "refs";'
        .         'delete ${__PACKAGE__."::"}{"__' . uc($type) . '__"};'
        .     '}'
        . '}';

    lex_stuff($preamble);
    {
        local $CURRENT_META = $meta;
        if (my $code = parse_block(1)) {
            $code->();
            $g->dismiss;
        }
    }

    run_traits($meta, @traits);

    $meta->FINALIZE;

    return (sub { }, 1);
}

sub method { }

sub method_parser {
    my ($type) = @_;
    lex_read_space;

    my $name = parse_name($type);

    lex_read_space;

    my ($invocant, @prototype) = parse_prototype($name);
    $invocant //= '$self';

    lex_read_space;

    my @traits = parse_traits();

    lex_read_space;

    if (lex_peek eq ';' || lex_peek eq '}') {
        lex_read if lex_peek eq ';';

        $CURRENT_META->add_required_method($name);

        return (sub { }, 1);
    }

    syntax_error("Non-required ${type}s require a body")
        unless lex_peek eq '{';
    lex_read;

    my $preamble = '{'
        . 'my ' . $invocant . ' = shift;'
        . 'use twigils "fatal_lookup_errors", allowed_twigils => "!";'
        . '();';

    # this is our method preamble, it
    # basically creates a method local
    # variable for each attribute, then
    # it will cast the magic on it to
    # make sure that any change in value
    # is stored in the fieldhash storage
    foreach my $attr (map { $_->name } $CURRENT_META->attributes) {
        $preamble .=
            'intro_twigil_my_var ' . $attr . ';'
          . 'Variable::Magic::cast('
              . $attr . ', '
              . '(Scalar::Util::blessed(' . $invocant . ') '
                  . '? $' . __PACKAGE__ . '::ATTR_WIZARD'
                  . ': $' . __PACKAGE__ . '::ERR_WIZARD'
              . '), '
              . '(Scalar::Util::blessed(' . $invocant . ') '
                  . '? {'
                      . 'meta => $' . $CURRENT_META->name . '::METACLASS,'
                      . 'self => ' . $invocant . ','
                      . 'name => q[' . $attr . ']'
                  . '}'
                  . ': q[' . $attr . ']'
              . '), '
          . ');';
    }

    # now we unpack the prototype
    if (@prototype) {
        my @names = map { $_->{name} } @prototype;
        $preamble .= 'my (' . join(', ', @names) . ') = @_;';

        for my $var (grep { defined $_->{default} } @prototype) {
            $preamble .=
                $var->{name} . ' = ' . stuff_value($var->{default}) . '->()'
                  . ' unless @_ > ' . $var->{index} . ';';
        }
    }

    my $code = parse_stuff_with_values($preamble, \&parse_block);
    syntax_error() unless $code;

    $CURRENT_META->add_method(
        $CURRENT_META->method_class->new(
            name => $name,
            body => Sub::Name::subname((join '::' => $CURRENT_META->name, $name), $code),
        )
    );

    run_traits($CURRENT_META->get_method($name), @traits);

    return (sub { }, 1);
}

sub has { }

sub has_parser {
    lex_read_space;

    syntax_error("Invalid attribute name " . read_tokenish())
        unless lex_peek eq '$';
    lex_read;

    die "Invalid attribute name \$" . read_tokenish()
        unless lex_peek eq '!';
    lex_read;


    my $name = '$!' . parse_name('attribute');

    lex_read_space;

    my @traits = parse_traits();

    lex_read_space;

    my $default;
    if (lex_peek eq '=') {
        lex_read;
        lex_read_space;
        $default = parse_fullexpr;
    }

    lex_read_space;

    if (lex_peek eq ';') {
        lex_read;
    }
    elsif (lex_peek ne '}') {
        syntax_error("Couldn't parse attribute $name");
    }

    $CURRENT_META->add_attribute(
        $CURRENT_META->attribute_class->new(
            name    => $name,
            default => \$default,
        )
    );

    run_traits($CURRENT_META->get_attribute($name), @traits);

    return (sub { }, 1);
}

sub parse_modifier_with_single_value {
    my ($modifier) = @_;

    my $modifier_length = length $modifier;

    return unless lex_peek($modifier_length + 1) =~ /^$modifier\b/;

    lex_read($modifier_length);
    lex_read_space;

    my $name = parse_name(($modifier eq 'extends' ? 'class' : $modifier), 1);

    return $name;
}

sub parse_modifier_with_multiple_values {
    my ($modifier) = @_;

    my $modifier_length = length $modifier;

    return unless lex_peek($modifier_length + 1) =~ /^$modifier\b/;

    lex_read($modifier_length);
    lex_read_space;

    my @names;

    do {
        my $name = parse_name('role', 1);
        push @names, $name;
        lex_read_space;
    } while (lex_peek eq ',' && do { lex_read; lex_read_space; 1 });

    return @names;
}

sub parse_traits {
    return unless lex_peek(3) =~ /^is\b/;

    lex_read(2);
    lex_read_space;

    my @traits;

    do {
        my $name = parse_name('trait', 1);
        my $params;
        if (lex_peek eq '(') {
            lex_read;
            $params = parse_fullexpr;
            syntax_error("Unterminated parameter list for trait $name")
                unless lex_peek eq ')';
            lex_read;
        }
        push @traits, { name => $name, params => $params };
        lex_read_space;
    } while (lex_peek eq ',' && do { lex_read; lex_read_space; 1 });

    return @traits;
}

sub run_traits {
    my ($meta, @traits) = @_;

    my $meta_stuff = stuff_value($meta);

    my $code = '{';

    for my $trait (@traits) {
        if ($trait->{params}) {
            $code .= 'mop::traits::util::apply_trait(\&' . $trait->{name} . ', '
                . "$meta_stuff,"
                . stuff_value($trait->{params}) . '->()'
            . ');';
        }
        else {
            $code .= 'mop::traits::util::apply_trait(\&' . $trait->{name} . ", $meta_stuff);";
        }
    }

    $code .= '}';

    my $traits_code = parse_stuff_with_values($code, \&parse_block);
    syntax_error() unless $traits_code;
    $traits_code->();
}

sub parse_prototype {
    my ($method_name) = @_;
    return unless lex_peek eq '(';

    lex_read;
    lex_read_space;

    if (lex_peek eq ')') {
        lex_read;
        return;
    }

    my $invocant;
    my $seen_slurpy;
    my @vars;
    while ((my $sigil = lex_peek) ne ')') {
        my $var = {};
        syntax_error("Invalid sigil: $sigil")
            unless $sigil eq '$' || $sigil eq '@' || $sigil eq '%';
        syntax_error("Can't declare parameters after a slurpy parameter")
            if $seen_slurpy;

        $seen_slurpy = 1 if $sigil eq '@' || $sigil eq '%';

        lex_read;
        lex_read_space;
        my $name = parse_name('argument', 0);
        lex_read_space;

        $var->{name} = "$sigil$name";

        if (lex_peek eq '=') {
            lex_read;
            lex_read_space;
            $var->{default} = parse_arithexpr;
            lex_read_space;
        }

        if (lex_peek eq ':') {
            syntax_error("Cannot specify multiple invocants")
                if $invocant;
            syntax_error("Cannot specify a default for the invocant")
                if $var->{default};
            $invocant = $var->{name};
            lex_read;
            lex_read_space;
        }
        else {
            $var->{index} = @vars;
            push @vars, $var;

            syntax_error("Unterminated prototype for $method_name")
                unless lex_peek eq ')' || lex_peek eq ',';

            if (lex_peek eq ',') {
                lex_read;
                lex_read_space;
            }
        }
    }

    lex_read;

    return $invocant, @vars;
}

# XXX push back into Parse::Keyword?
sub parse_name {
    my ($what, $allow_package) = @_;
    my $name = '';

    my $ascii_start_rx = my $start_rx = qr/^[A-Za-z_]/;
    my $ascii_cont_rx  = my $cont_rx  = qr/^[A-Za-z0-9_]/;

    my $char_rx = $start_rx;

    while (1) {
        my $char = lex_peek;
        # delay loading utf8 stuff until necessary
        # if ($start_rx == $ascii_start_rx && ord($char) > 127) {
        #     warn ord($char);
        #     # XXX this isn't quite right, i think, but probably close enough
        #     # for now?
        #     my $new_start_rx = eval 'qr/^[\p{ID_Start}_]$/';
        #     my $new_cont_rx  = eval 'qr/^\p{ID_Continue}$/';
        #     $char_rx = $char_rx == $start_rx ? $new_start_rx : $new_cont_rx;
        #     $start_rx = $new_start_rx;
        #     $cont_rx = $new_cont_rx;
        # }
        last unless length $char;
        if ($char =~ $char_rx) {
            $name .= $char;
            lex_read;
            $char_rx = $cont_rx;
        }
        elsif ($allow_package && $char eq ':') {
            if (lex_peek(3) !~ /^::(?:[^:]|$)/) {
                my $invalid = $name . read_tokenish();
                syntax_error("Invalid identifier: $invalid");
            }
            $name .= '::';
            lex_read(2);
        }
        else {
            last;
        }
    }

    syntax_error(read_tokenish() . " is not a valid $what name")
        unless length $name;

    return $name;
}

# this is a little hack to be able to inject actual values into the thing we
# want to parse (what we would normally do by inserting OP_CONST nodes into the
# optree if we were building it manually). we insert a constant sub into a
# private stash, and return the name of that sub. then, when that sub is
# parsed, it'll be turned into an OP_CONST during constant folding, at which
# point we can remove the sub (to avoid issues with holding onto refs longer
# than we should).
{
    my @guards;
    sub stuff_value {
        my ($value) = @_;
        state $index = 1;
        my $name = "value$index";
        my $const = "mop::internals::syntax::STUFF::$name";
        {
            no strict 'refs';
            *$const = sub () { $value };
        }
        push @guards, guard {
            delete $mop::internals::syntax::STUFF::{"$name"};
        };
        $index++;
        return $const;
    }

    sub parse_stuff_with_values {
        my ($code, $parser) = @_;
        lex_stuff($code);
        my $ret = $parser->();
        @guards = ();
        $ret;
    }
}

sub read_tokenish {
    my $token = '';
    if ((my $next = lex_peek) =~ /[\$\@\%\!:]/) {
        $token .= $next;
        lex_read;
    }
    while ((my $next = lex_peek) =~ /\S/) {
        $token .= $next;
        lex_read;
        last if ($next . lex_peek) =~ /^\S\b/;
    }
    return $token;
}

sub syntax_error {
    my ($err) = @_;
    $err //= $@;
    die $err if ref $err;
    die(
        join("",
            ($err ? ($@ ? $err : Carp::shortmess($err)) : ()),
            "Execution of $0 aborted due to compilation errors.\n"
        )
    );
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

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Infinity Interactive.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=begin Pod::Coverage

  class
  role
  namespace_parser
  method
  method_parser
  has
  has_parser
  parse_modifier_with_single_value
  parse_modifier_with_multiple_values
  parse_traits
  run_traits
  parse_prototype
  parse_name
  stuff_value
  parse_stuff_with_values
  read_tokenish
  syntax_error

=end Pod::Coverage

=cut







