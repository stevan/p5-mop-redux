#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

use B::Deparse;

class Foo {
    method foo { __CLASS__ }
    method bar { __PACKAGE__ }
}
{
    my $method = mop::meta('Foo')->get_method('foo');
    my $body = mop::meta($method)->get_attribute('$!body')->fetch_data_in_slot_for($method);
    unlike(B::Deparse->new->coderef2text($body), qr/__CLASS__/);
}

is(Foo->foo, 'Foo');
is(Foo->bar, 'main');

role Bar {
    method foo { __ROLE__ }
    method bar { __PACKAGE__ }
}
class Baz with Bar { }
{
    my $method = mop::meta('Bar')->get_method('foo');
    my $body = mop::meta($method)->get_attribute('$!body')->fetch_data_in_slot_for($method);
    unlike(B::Deparse->new->coderef2text($body), qr/__ROLE__/);
}

is(Baz->foo, 'Bar');
is(Baz->bar, 'main');

eval "
class Error {
    method foo { __ROLE__ }
}
";
like($@, qr/Bareword "__ROLE__" not allowed/);

eval "
role Error2 {
    method foo { __CLASS__ }
}
";
like($@, qr/Bareword "__CLASS__" not allowed/);

eval "__CLASS__";
like($@, qr/Bareword "__CLASS__" not allowed/);
eval "__ROLE__";
like($@, qr/Bareword "__ROLE__" not allowed/);

package InPackage {
    use mop;

    class Foo {
        method foo { __CLASS__ }
        method bar { __PACKAGE__ }
    }
    role Bar {
        method foo { __ROLE__ }
        method bar { __PACKAGE__ }
    }
    class Baz with InPackage::Bar { }
}

is(InPackage::Foo->foo, 'InPackage::Foo');
is(InPackage::Foo->bar, 'InPackage');
is(InPackage::Baz->foo, 'InPackage::Bar');
is(InPackage::Baz->bar, 'InPackage');

done_testing;
