use strict;
use warnings;
use ExtUtils::MakeMaker;

use lib 'inc';
use MMHelper;

eval MMHelper::header_generator() or die $@;

WriteMakefile(
    NAME => 'twigil',
    MMHelper::mm_args,
);
