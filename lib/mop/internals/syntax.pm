package mop::internals::syntax;

use v5.16;
use warnings;

use Scope::Guard qw[ guard ];
use Variable::Magic       qw[ wizard ];

use B::Hooks::EndOfScope ();
use Scalar::Util    ();
use Sub::Name       ();
use Module::Runtime ();
use version         ();

use Parse::Keyword {
    class     => \&namespace_parser,
    role      => \&namespace_parser,
    method    => \&generic_method_parser,
    submethod => \&generic_method_parser,
    has       => \&has_parser,
};

# keep the local package name around
our $CURRENT_CLASS_NAME;

# Keep a list of attributes currently
# being compiled in the class because
# we need to alias them in the method
# preamble.
our $CURRENT_ATTRIBUTE_LIST;

# So this will apply magic to the aliased
# attributes that we put in the method
# preamble. For `data`, it takes an HASH-ref
# containing the invocant id, the current
# meta object and the name of the attribute
# we are trying to get/set. Then when our
# attribute variable is read from or written
# to it will get/set that data to the
# underlying fieldhash storage.
our $ATTR_WIZARD = Variable::Magic::wizard(
    data => sub {
        my (undef, $config) = @_;
        return $config;
    },
    get  => sub {
        my ($var, $config) = @_;
        my $attr = $config->{'meta'}->get_attribute( $config->{'name'} );
        ${ $var } = $attr->fetch_data_in_slot_for( $config->{'oid'} );
        ();
    },
    set  => sub {
        my ($value, $config) = @_;
        my $attr = $config->{'meta'}->get_attribute( $config->{'name'} );
        $attr->store_data_in_slot_for( $config->{'oid'}, ${ $value } );
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
our $ERR_WIZARD = Variable::Magic::wizard(
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

sub setup_for {
    shift;
    my ($pkg) = @_;
    {
        no strict 'refs';
        *{ $pkg . '::class'     } = \&class;
        *{ $pkg . '::role'      } = \&role;
        *{ $pkg . '::method'    } = \&method;
        *{ $pkg . '::submethod' } = \&submethod;
        *{ $pkg . '::has'       } = \&has;
    }
}

sub class {
    my ($pkg) = @_;
    1;
}

sub role {
    my ($pkg) = @_;
    1;
}

sub namespace_parser {
    my ($type) = @_;

    lex_read_space;

    my $name   = parse_name($type, 1);
    my $caller = compiling_package;
    my $pkg    = $caller eq 'main'
        ? $name
        : join "::" => $caller, $name;

    lex_read_space;

    my $version;
    if (lex_peek(40) =~ / \A ($version::LAX) (?:\s|\{) /x) {
        lex_read(length($1));
        $version = version::is_strict($1) ? eval($1) : $1 eq 'undef' ? undef : $1;
    }

    lex_read_space;

    my @classes_to_load;

    my $extends;
    if ($extends = parse_modifier_with_single_value('extends')) {
        push @classes_to_load => $extends;
    }

    lex_read_space;

    my @with;
    if (@with = parse_modifier_with_multiple_values('with')) {
        push @classes_to_load => @with;
    }

    lex_read_space;

    my $metaclass;
    if ($metaclass = parse_modifier_with_single_value('metaclass')) {
        push @classes_to_load => $metaclass;
    }

    lex_read_space;

    my @traits = parse_traits();

    lex_read_space;

    for my $class (@classes_to_load) {
        next if mop::util::has_meta($class);
        Module::Runtime::use_package_optimistically($class);
    }

    die "$type must be followed by a block" unless lex_peek eq '{';

    local $CURRENT_CLASS_NAME     = $pkg;
    local $CURRENT_ATTRIBUTE_LIST = [];

    mro::set_mro($pkg, 'mop');

    my $meta = ($type eq 'class' ? \&build_class : \&build_role)->(
        name      => $pkg,
        extends   => $extends,
        with      => \@with,
        metaclass => $metaclass,
        version   => $version,
    );
    mop::util::get_stash_for($pkg)->add_symbol('$METACLASS', \$meta);
    my $g = guard {
        mop::util::get_stash_for($pkg)->remove_symbol('$METACLASS');
    };

    if (my $code = parse_block(1)) {
        local ${^META} = $meta;
        if ($type eq 'class') {
            local ${^CLASS} = $meta;
            $code->();
        }
        else {
            local ${^ROLE} = $meta;
            $code->();
        }

        $g->dismiss;
    }

    run_traits($meta, @traits);

    $meta->FINALIZE;

    # NOTE:
    # Now clean up the package we imported
    # into and do it at the right time in
    # the compilaton cycle.
    #
    # For a more detailed explination about
    # why we are doing it this way, see the
    # comment in the following test:
    #
    #     t/120-bugs/001-plack-parser-bug.t
    #
    # it will give you detailed explination
    # as to why we are doing this.
    #
    # In short, don't muck with this unless
    # you really understand the comments in
    # that test.
    # - SL
    {
        lex_stuff('{UNITCHECK{B::Hooks::EndOfScope::on_scope_end { mop->unimport }}}');
        my $ret = parse_block();
        $ret->();
    }

    return (sub { $pkg }, 1);
}

sub build_class {
    my %metadata = @_;

    my $class_Class = 'mop::class';
    if ( defined $metadata{ 'metaclass' } ) {
        $class_Class = delete $metadata{ 'metaclass' };
    }

    if ( defined $metadata{ 'extends' } ) {
        $metadata{ 'superclass' } = delete $metadata{ 'extends' };
    } else {
        $metadata{ 'superclass' } = 'mop::object';
    }

    if ( defined $metadata{ 'with' } ) {
        $metadata{ 'with' }  = [ $metadata{ 'with' } ] unless ref($metadata{ 'with' }) eq q(ARRAY);
        $metadata{ 'roles' } = [ map { mop::util::find_meta($_) } @{ delete $metadata{ 'with' } } ];
    }

    $class_Class->new(%metadata);
}

sub build_role {
    my %metadata = @_;

    if ( defined $metadata{ 'with' } ) {
        $metadata{ 'with' }  = [ $metadata{ 'with' } ] unless ref($metadata{ 'with' }) eq q(ARRAY);
        $metadata{ 'roles' } = [ map { mop::util::find_meta($_) } @{ delete $metadata{ 'with' } } ];
    }

    mop::role->new(%metadata);
}

sub method {
    my ($name, $body, @traits) = @_;

    if ($body) {
        ${^META}->add_method(
            ${^META}->method_class->new(
                name => $name,
                body => Sub::Name::subname((join '::' => $CURRENT_CLASS_NAME, $name), $body),
            )
        );
    }
    else {
        ${^META}->add_required_method($name);
    }

    run_traits(${^META}->get_method($name), @traits);
}

sub submethod {
    my ($name, $body, @traits) = @_;

    die "submethods are not supported in roles"
        if ${^META}->isa('mop::role');

    ${^META}->add_submethod(
        ${^META}->submethod_class->new(
            name => $name,
            body => Sub::Name::subname((join '::' => $CURRENT_CLASS_NAME, $name), $body),
        )
    );

    run_traits(${^META}->get_submethod($name), @traits);
}

sub generic_method_parser {
    my ($type) = @_;
    lex_read_space;

    my $name = parse_name($type);

    lex_read_space;

    my @prototype = parse_prototype($name);

    lex_read_space;

    my @traits = parse_traits();

    lex_read_space;

    if (lex_peek eq ';') {
        lex_read;
        return (sub { $name }, 1);
    }

    die "Non-required ${type}s require a body" unless lex_peek eq '{';
    lex_read;

    my $preamble = '{'
        . 'my ($self, $class);'
        . 'if (Scalar::Util::blessed($_[0])) {'
           . '$self  = shift(@_);'
           . '$class = Scalar::Util::blessed($self);'
        . '} else {'
           . '$class = shift(@_);'
        . '}'
        . 'local ${^CALLER} = [ $self, q[' . $name . '], $' . $CURRENT_CLASS_NAME . '::METACLASS ];';

    # this is our method preamble, it
    # basically creates a method local
    # variable for each attribute, then
    # it will cast the magic on it to
    # make sure that any change in value
    # is stored in the fieldhash storage
    foreach my $attr (@{ $CURRENT_ATTRIBUTE_LIST }) {
        $preamble .=
            'my ' . $attr . ';'
          . 'Variable::Magic::cast('
              . $attr . ', '
              . '(Scalar::Util::blessed($self) '
                  . '? $' . __PACKAGE__ . '::ATTR_WIZARD'
                  . ': $' . __PACKAGE__ . '::ERR_WIZARD'
              . '), '
              . '(Scalar::Util::blessed($self) '
                  . '? {'
                      . 'meta => $' . $CURRENT_CLASS_NAME . '::METACLASS,'
                      . 'oid  => mop::util::get_object_id($self),'
                      . 'name => q[' . $attr . ']'
                  . '}'
                  . ': q[' . $attr . ']'
              . '), '
          . ');';
    }

    $preamble .= '{';

    # inject this after the attributes so that 
    # it is overriding the attr and not the
    # other way around.
    if (@prototype) {
        my @names = map { $_->{name} } @prototype;
        $preamble .= 'my (' . join(', ', @names) . ') = @_;';

        for my $var (grep { defined $_->{default} } @prototype) {
            $preamble .=
                $var->{name} . ' = ' . stuff_value($var->{default}) . '->()'
                  . ' unless @_ > ' . $var->{index} . ';';
        }
    }

    $preamble .= 'BEGIN{B::Hooks::EndOfScope::on_scope_end { Parse::Keyword::lex_stuff("}") }}';

    my $code = parse_stuff_with_values($preamble, \&parse_block);

    return (sub { ($name, $code, @traits) }, 1);
}

sub has {
    my ($name, $metaclass, $default, @traits) = @_;

    my $attribute_Class = $metaclass || ${^META}->attribute_class;

    ${^META}->add_attribute(
        $attribute_Class->new(
            name    => $name,
            default => \$default,
        )
    );

    run_traits(${^META}->get_attribute($name), @traits);
}

sub has_parser {
    lex_read_space;

    die "Invalid attribute name " . read_tokenish() unless lex_peek eq '$';
    lex_read;

    my $name = '$' . parse_name('attribute');

    lex_read_space;

    my $metaclass;
    if ($metaclass = parse_modifier_with_single_value('metaclass')) {
        Module::Runtime::use_package_optimistically($metaclass);
    }

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
        die "Couldn't parse attribute $name";
    }

    push @{ $CURRENT_ATTRIBUTE_LIST } => $name;

    return (sub { ($name, $metaclass, $default, @traits) }, 1);
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
            die "Unterminated parameter list for trait $name"
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
            $code .= $trait->{name} . '('
                . "$meta_stuff,"
                . stuff_value($trait->{params}) . '->()'
            . ');';
        }
        else {
            $code .= $trait->{name} . "($meta_stuff);";
        }
    }

    $code .= '}';

    my $traits_code = parse_stuff_with_values($code, \&parse_block);
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

    my $seen_slurpy;
    my @vars;
    while ((my $sigil = lex_peek) ne ')') {
        my $var = {};
        die "Invalid sigil: $sigil"
            unless $sigil eq '$' || $sigil eq '@' || $sigil eq '%';
        die "Can't declare parameters after a slurpy parameter"
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
        }

        $var->{index} = @vars;

        push @vars, $var;

        die "Unterminated prototype for $method_name"
            unless lex_peek eq ')' || lex_peek eq ',';

        if (lex_peek eq ',') {
            lex_read;
            lex_read_space;
        }
    }

    lex_read;

    return @vars;
}

# XXX push back into Parse::Keyword?
sub parse_name {
    my ($what, $allow_package) = @_;
    my $name = '';

    # XXX this isn't quite right, i think, but probably close enough for now?
    my $start_rx = qr/^[\p{ID_Start}_]$/;
    my $cont_rx  = qr/^\p{ID_Continue}$/;

    my $char_rx = $start_rx;

    while (1) {
        my $char = lex_peek;
        last unless length $char;
        if ($char =~ $char_rx) {
            $name .= $char;
            lex_read;
            $char_rx = $cont_rx;
        }
        elsif ($allow_package && $char eq ':') {
            if (lex_peek(3) !~ /^::(?:[^:]|$)/) {
                my $invalid = $name . read_tokenish();
                die "Invalid identifier: $invalid";
            }
            $name .= '::';
            lex_read(2);
        }
        else {
            last;
        }
    }

    die read_tokenish() . " is not a valid $what name" unless length $name;

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
        my $symbol = '&value' . $index;
        my $stash = mop::util::get_stash_for('mop::internals::syntax::STUFF');
        $stash->add_symbol($symbol, sub () { $value });
        my $code = "mop::internals::syntax::STUFF::value$index";
        push @guards, guard { $stash->remove_symbol($symbol); };
        $index++;
        return $code;
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
    if ((my $next = lex_peek) =~ /[\$\@\%]/) {
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

1;

__END__

=pod

=head1 NAME

mop::internal::syntax

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







