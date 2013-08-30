use strict;
use warnings;
use Test::More;

use twigil;

twigil::intro_twigil_var('$!foo');
twigil::intro_twigil_var('$.bar');

$!=123;
is 0+$!, 123;
$.=123;
is$., 123;

$!foo = 1;
$.bar = 2;

is $!foo, 1;
is $.bar, 2;

done_testing;
