package mop::internals::syntax;

use v5.16;
use warnings;

use Hash::Util::FieldHash qw[ fieldhash ];
use Variable::Magic       qw[ wizard ];

use B::Hooks::EndOfScope ();
use Scalar::Util    ();
use Sub::Name       ();
use Module::Runtime ();

use Parse::Keyword {
    class     => sub { namespace_parser('CLASS', \&build_class) },
    role      => sub { namespace_parser('ROLE', \&build_role) },
    method    => sub { generic_method_parser('method') },
    submethod => sub { generic_method_parser('submethod') },
    has       => \&has_parser,
};

# keep the local package name around
fieldhash my %CURRENT_CLASS_NAME;

# Keep a list of attributes currently
# being compiled in the class because
# we need to alias them in the method
# preamble.
fieldhash my %CURRENT_ATTRIBUTE_LIST;

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
    mop::util::get_stash_for($pkg)->remove_glob($_)
        for qw(class role method submethod has);
    1;
}

sub role {
    my ($pkg) = @_;
    mop::util::get_stash_for($pkg)->remove_glob($_)
        for qw(class role method submethod has);
    1;
}

sub namespace_parser {
    my ($type, $builder) = @_;

    lex_read_space;

    my $name   = parse_name(lc($type), 1);
    my $caller = compiling_package;
    my $pkg    = $name =~ /::/ || $caller eq 'main'
        ? $name
        : join "::" => $caller, $name;

    lex_read_space;

    my $metadata;
    if (lex_peek eq '(') {
        lex_read;
        lex_read_space;
        $metadata = parse_listexpr;
        lex_read_space;
        die "Unterminated \L$type\E metadata for $name" unless lex_peek eq ')';
        lex_read;
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

    mro::set_mro($pkg, 'mop');

    my $meta = $builder->(
        name      => $pkg,
        extends   => $extends,
        with      => \@with,
        metaclass => $metaclass,
        $metadata ? ($metadata->()) : (),
    );
    mop::util::get_stash_for($pkg)->add_symbol('$METACLASS', \$meta);

    $CURRENT_CLASS_NAME{''}     = $pkg;
    $CURRENT_ATTRIBUTE_LIST{''} = [];

    die "\L$type\E must be followed by a block" unless lex_peek eq '{';
    lex_read;

    my $preamble = '{';

    $preamble .= 'local ${^' . $type. '} = $' . $pkg . '::METACLASS;'
               . 'local ${^META} = $' . $pkg . '::METACLASS;';

    lex_stuff($preamble);

    {
        local $@;
        my $code = parse_block(1);
        die $@ if $@;
        $code->();
    }

    run_traits($meta, @traits);

    $meta->FINALIZE;

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
                body => Sub::Name::subname($name, $body),
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

    ${^META}->add_submethod(
        ${^META}->submethod_class->new(
            name => $name,
            body => Sub::Name::subname($name, $body),
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
        . 'local ${^CALLER} = [ $self, q[' . $name . '], $' . $CURRENT_CLASS_NAME{''} . '::METACLASS ];';

    # this is our method preamble, it
    # basically creates a method local
    # variable for each attribute, then
    # it will cast the magic on it to
    # make sure that any change in value
    # is stored in the fieldhash storage
    foreach my $attr (@{ $CURRENT_ATTRIBUTE_LIST{''} }) {
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
                      . 'meta => $' . $CURRENT_CLASS_NAME{''} . '::METACLASS,'
                      . 'oid  => mop::util::get_object_id($self),'
                      . 'name => q[' . $attr . ']'
                  . '}'
                  . ': q[' . $attr . ']'
              . '), '
          . ');';
    }

    local $mop::internals::syntax::{'DEFAULTS::'};

    # inject this after the attributes so that 
    # you it is overriding the attr and not the
    # other way around.
    if (@prototype) {
        my @names = map { $_->{name} } @prototype;
        $preamble .= 'my (' . join(', ', @names) . ') = @_;';

        my $index = 1;
        for my $var (grep { defined $_->{default} } @prototype) {
            {
                no strict 'refs';
                *{ __PACKAGE__ . '::DEFAULTS::def' . $index } = sub () {
                    $var->{default}
                };
            }
            $preamble .= $var->{name} . ' = ' . __PACKAGE__ . '::DEFAULTS::def' . $index . '->()' . ' unless @_ > ' . $var->{index} . ';';
            $index++;
        }
    }

    $preamble .= '{'
                   . 'BEGIN { B::Hooks::EndOfScope::on_scope_end {'
                       . 'Parse::Keyword::lex_stuff("}");'
                   . '} }';

    lex_stuff($preamble);

    my $code = parse_block;

    return (sub { ($name, $code, @traits) }, 1);
}

sub has {
    my ($name, $metadata, $default, @traits) = @_;

    my %metadata = $metadata ? ($metadata->()) : ();

    my $attribute_Class = ${^META}->attribute_class;
    if ( exists $metadata{ 'metaclass' } ) {
        $attribute_Class = delete $metadata{ 'metaclass' };
    }

    ${^META}->add_attribute(
        $attribute_Class->new(
            name    => $name,
            default => \$default,
            %metadata,
        )
    );

    run_traits(${^META}->get_attribute($name), @traits);
}

sub has_parser {
    lex_read_space;

    die "invalid attribute name " . read_tokenish() unless lex_peek eq '$';
    lex_read;

    my $name = '$' . parse_name('attribute');

    lex_read_space;

    my $metadata;
    if (lex_peek eq '(') {
        lex_read;
        lex_read_space;
        $metadata = parse_listexpr;
        lex_read_space;
        die "Unterminated attribute metadata for $name" unless lex_peek eq ')';
        lex_read;
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

    die "Couldn't parse attribute $name" unless lex_peek eq ';';
    lex_read;

    push @{ $CURRENT_ATTRIBUTE_LIST{''} } => $name;

    return (sub { ($name, $metadata, $default, @traits) }, 1);
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

    local $mop::internals::syntax::{'TRAITS::'};

    {
        no strict 'refs';
        *{ __PACKAGE__ . '::TRAITS::meta' } = sub () { $meta };
    }

    my $code = '{';

    my $index = 1;
    for my $trait (@traits) {
        if ($trait->{params}) {
            {
                no strict 'refs';
                *{ __PACKAGE__ . '::TRAITS::trait' . $index } = sub () {
                    $trait->{params}
                };
            }
            $code .= $trait->{name} . '('
                . 'mop::internals::syntax::TRAITS::meta(),'
                . 'mop::internals::syntax::TRAITS::trait' . $index . '()->()'
            . ');';
            $index++;
        }
        else {
            $code .= $trait->{name} . '(mop::internals::syntax::TRAITS::meta());';
        }
    }

    $code .= '}';

    lex_stuff($code);
    my $traits_code = parse_block;
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







