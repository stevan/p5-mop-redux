#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

my ($built, $demolished);
BEGIN { ($built, $demolished) = (0, 0) }
class Meta extends mop::class {
    submethod BUILD    { $built++ }
    submethod DEMOLISH { $demolished++ }
}

BEGIN { is($built, 0); is($demolished, 0) }
class Foo metaclass Meta { }
BEGIN { is($built, 1); is($demolished, 0) }
class Bar metaclass Meta { }
BEGIN { is($built, 2); is($demolished, 0) }
class Baz metaclass Meta { }
BEGIN { is($built, 3); is($demolished, 0) }

mop::util::uninstall_meta(mop::get_meta('Foo'));
is($built, 3);
is($demolished, 1);
mop::util::uninstall_meta(mop::get_meta('Bar'));
is($built, 3);
{ local $TODO = "these DEMOLISH methods don't get called at all, for reasons i don't understand at all (seems to be related to the no-fetch bug in the mro)";
is($demolished, 2);
}
mop::util::uninstall_meta(mop::get_meta('Baz'));
is($built, 3);
{ local $TODO = "these DEMOLISH methods don't get called at all, for reasons i don't understand at all (seems to be related to the no-fetch bug in the mro)";
is($demolished, 3);
}

done_testing;
