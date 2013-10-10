#!perl

use strict;
use warnings;

use Test::More;

use mop;

{
    package My::Foo;
    use strict;
    use warnings;
    use mop;

    class Bar {
        method bar { Baz::Gorch->new }
    }

    class Baz::Gorch {}

    class ::Blorg {}
}

my $bar = My::Foo::Bar->new;
isa_ok($bar, 'My::Foo::Bar');

my $result = eval { $bar->bar };
is($@, "", '... worked successfully');
isa_ok($result, 'Baz::Gorch');

my $blorg = Blorg->new;
isa_ok($blorg, 'Blorg');

eval { My::Foo::Blorg->new };
like($@, qr/^Can't locate object method "new" via package "My::Foo::Blorg"/);

done_testing;
