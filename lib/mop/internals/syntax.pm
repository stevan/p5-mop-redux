package mop::internals::syntax;

use v5.16;
use warnings;

use Scope::Guard    qw[ guard ];

use B::Hooks::EndOfScope ();
use Carp              ();
use Scalar::Util      ();
use version           ();
use Devel::CallParser ();

use Parse::Keyword {
    class  => \&namespace_parser,
    role   => \&namespace_parser,
};

my @available_keywords = qw(class role method has);

# keep the local metaclass around
our $CURRENT_META;

# The list of attribute names declared so far during the compilation of a
# namespace block, used to declare lexicals in methods as they're compiled.
our @CURRENT_ATTRIBUTE_NAMES;

sub setup_for {
    my ($pkg) = @_;

    $^H{__PACKAGE__ . '/twigils'} = 1;
    mop::_install_sub($pkg, 'mop::internals::syntax', $_)
        for @available_keywords;
}

sub teardown_for {
    my ($pkg) = @_;

    mop::_uninstall_sub($pkg, $_)
        for @available_keywords;
}

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
        $metaclass = $^H{"mop/default_${type}_metaclass"} // "mop::$type";
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

    die "The metaclass for $pkg ($metaclass) does not inherit from mop::$type"
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
        local @CURRENT_ATTRIBUTE_NAMES = ();
        if (my $code = parse_block(1)) {
            run_traits($meta, @traits);
            $meta->FINALIZE;
            $code->();
            $g->dismiss;
        }
    }

    return (sub { }, 1);
}

sub method { }

sub add_method {
    my ($name, $body, @traits) = @_;

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

    return;
}

sub has { }

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

=for Pod::Coverage .+

=cut







