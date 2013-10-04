#!perl

use strict;
use warnings;

use Test::More;

use FindBin;
use lib "$FindBin::Bin/../lib";

=pod

So, this is a tricky problem actually.

When the Parse::Keyword branch landed, there was
code inside the mop::internals::syntax::{class,role}
that would attempt to clean out the package imports
that it had done (class, role, has & method).
This works fine for classes being created in main::
(essentially classes created in the same package).
However it failed for the following:

in Foo/Bar.pm
    package Foo;
    use mop;

    class Bar { ... }

in Foo/Bar/Baz.pm
    package Foo::Bar;
    use mop;

    class Baz extends Foo::Bar { ... }

And the reason it failed was that the symbol table
cleanup code in mop::internals::syntax::{class,role}
was basically running too early (and had a bug in it).

When Foo::Bar::Baz was loaded, the class would begin
parsing, it would encounter the extends definition,
then load Foo::Bar. Once Foo::Bar had been parsed
and compiled, it would then proceed to clean out the
symbol table imports from Foo::Bar. This would result
in a parse fail of the Foo::Bar class block.

This was wrong in two ways; first, it should have been
cleaning out the symbols from Foo and not Foo::Bar as
that was actually where they were imported, and second
it really needed to do the symbol table unimport at the
very last moment possible. Because just fixing the first
issue would not fix this:

in Foo/Gorch.pm
    package Foo;
    use mop;

    class Gorch extends Foo::Bar { ... }

In this case, Foo::Gorch would load Foo::Bar and
then Foo would get cleaned out too early and cause
a parse fail of the rest of Foo::Gorch.

So the way to solve the second issue can be seen at
the end of mop::internal::syntax::namespace_parser
right after the metaclass is finalized. It basically
injects a UNITCHECK block, which will fire at the
very end of compile time for that one specific
compilation unit. It then goes one further and hooks
an end-of-scope handler which in turn will clean
out the imported symbols.

=cut

# NOTE:
# if you uncommented either of
# these, it worked (see above
# for default as to why).
# - SL

#use Flack::Component;
#use Flack::Middleware;

use Flack::Middleware::AccessLog;

# NOTE:
# any changed made to this should
# run this code to make sure that
# the namespaces are properly
# cleaned out.
# - SL
#foreach my $pkg ('Flack', 'Flack::Component', 'Flack::Middleware', 'Flack::Middleware::AccessLog') {
#    warn "Symbols for $pkg\n";
#    warn((join "\n" => Package::Stash->new($pkg)->list_all_symbols) . "\n");
#    warn "-----------------\n";
#}

pass("... it worked");

done_testing;
